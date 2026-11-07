// The box: four slots, a sensor under each, and a Bluetooth radio that tells
// the phones connected to it when a slot fills or empties.
//
// It speaks the Portside dock protocol, version 1 — the same one as the dock
// with a current sensor on each pad — so the app needs one protocol, not two.
// The phone does the rest: each one connected hears the change, and the one
// that just started charging, with this radio right beside it, starts its
// evening (ReclaimKit/Dock/Box.swift has the same ids).
//
// Board: any ESP32 with Bluetooth LE — an ESP32-C3 or ESP32-S3 dev board, a
// Seeed XIAO ESP32-C3/S3. Not an ESP32-S2: it has no Bluetooth.
// Library: NimBLE-Arduino 2.x (checked against 2.5.1). Optional: Adafruit
// NeoPixel, for lights the box runs itself.
//
// docs/DOCK.md has the wiring, and how to flash it.

#include <NimBLEDevice.h>
#include <Wire.h>

// The radio has a fixed number of things it can do at once — advertising is
// one, each connected phone is another (6 in all on an ESP32-C3). NimBLE's
// connection limit lives in the library's nimconfig.h, and setting it past
// what the radio has doesn't fail the build: the board crashes on every boot
// with "assert failed: npl_freertos_mutex_pend", and never advertises. So the
// build fails here instead. On a C3 that means 5 at most: five phones in the
// house connected, and one more advertisement for the next.
#if defined(CONFIG_BT_CTRL_BLE_MAX_ACT) && CONFIG_BT_NIMBLE_MAX_CONNECTIONS >= CONFIG_BT_CTRL_BLE_MAX_ACT
#error "CONFIG_BT_NIMBLE_MAX_CONNECTIONS in NimBLE-Arduino's nimconfig.h is more than this chip's radio can hold; on an ESP32-C3 use 5"
#endif

// ---------------------------------------------------------------- wiring
// Each slot is read one of two ways, and a slot can use either.
//
// A digital input. An IR obstacle module (FC-51 and the like) pulls its output
// LOW when something is over it; so does a switch wired to ground. Set
// SLOT_ACTIVE to HIGH for a sensor that does the opposite. GPIO numbers, not
// the board's labels; on a XIAO ESP32-C3, D1–D4 are 3, 4, 5, 6. Not D0
// (GPIO 2), D8 or D9: the chip reads those while it boots, and a phone sitting
// in that slot at power-on could stop it starting. -1: not wired.
//
// Or an INA219 current sensor on the slot's charging cable, at an I2C address
// (0x40 unless its A0/A1 pads are bridged). A phone counts as in when it is
// drawing current — which is also what "was it me" on the phone asks. -1: none.
//
// As wired now (the ESP32-S3 dev board, 2026-11-07): one INA219 on slot 1,
// SDA on GPIO 9 and SCL on GPIO 8, the other slots not yet wired.
const int SLOTS = 4;
const int SLOT_PINS[SLOTS] = {-1, -1, -1, -1};
const int SLOT_ACTIVE = LOW;
const int SLOT_INA219[SLOTS] = {0x40, -1, -1, -1};
const int I2C_SDA = 9, I2C_SCL = 8;

// The INA219's shunt is 0.1 Ω (R100) and reads in steps of 10 µV: 0.1 mA each.
// Measured on the desk: an empty cable reads about 12 mA, with lone spikes to
// 300; a charging iPhone, 800–900. So a slot is read as the average of the
// last two seconds, and it takes 100 mA to come in and under 30 to go out.
const float MA_PER_STEP = 0.1;
const float IN_MA = 100, OUT_MA = 30;
const int AVERAGE_OVER = 20;      // samples, one per 100 ms

// The lights, if this board runs them: a strip with two LEDs per slot, slot 1
// first. -1 leaves the lights to something else (the WLED controller).
#define LIGHT_PIN -1
const int LEDS_PER_SLOT = 2;

// ---------------------------------------------------------------- the protocol, as in Box.swift
#define SERVICE_UUID   "6e400001-b5a3-f393-e0a9-0000706f7274"
#define SLOT_STATE_UUID "6e400010-b5a3-f393-e0a9-0000706f7274"
#define EVENT_UUID     "6e400011-b5a3-f393-e0a9-0000706f7274"
#define COMMAND_UUID   "6e400020-b5a3-f393-e0a9-0000706f7274"
const int PROTOCOL = 1;

// Slot state bytes. A presence sensor can only say "something is there", and
// a phone drawing current is charging, so every phone in reads as charging.
const uint8_t EMPTY = 0, CHARGING = 1;

// A phone being slid in rocks a sensor on and off; a slot has to say the same
// thing for this long before it counts.
const unsigned long SETTLE_MS = 400;

#if LIGHT_PIN >= 0
#include <Adafruit_NeoPixel.h>
Adafruit_NeoPixel strip(SLOTS * LEDS_PER_SLOT, LIGHT_PIN, NEO_GRB + NEO_KHZ800);
#endif

NimBLECharacteristic *slotStateChar;
NimBLECharacteristic *eventChar;
uint8_t reported = 0;            // what the phones were last told, a bit per slot
uint8_t seen = 0;                // what the sensors say right now
unsigned long seenSince = 0;

// Seconds since 1970 at the moment millis() was zero, once a phone has said
// what time it is. Until then, event times are seconds since power-on.
uint32_t epochAtBoot = 0;

// A colour per slot chosen by the app, or -1: the box's own warm light.
long lightOverride[SLOTS] = {-1, -1, -1, -1};

// Every phone in the house stays connected, so as each one connects the box
// has to go straight back to advertising for the next.
//
// `override` on every callback, deliberately. NimBLE-Arduino changed these
// signatures between 1.4 and 2.x; without it, a sketch written for the other
// version compiles cleanly and the callbacks are simply never called — a box
// that takes one phone and then goes quiet.
class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &info) override {
    Serial.printf("phone connected (%d now)\n", server->getConnectedCount());
    NimBLEDevice::startAdvertising();
  }
  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &info, int reason) override {
    Serial.printf("phone left (%d now)\n", server->getConnectedCount());
    NimBLEDevice::startAdvertising();
  }
};

uint32_t now() { return epochAtBoot + millis() / 1000; }

void send(const char *json) {
  eventChar->setValue((const uint8_t *)json, strlen(json));
  eventChar->notify();
  Serial.println(json);
}

// ---------------------------------------------------------------- the lights

void light() {
#if LIGHT_PIN >= 0
  for (int i = 0; i < SLOTS; i++) {
    // Warm, and low: it sits in a room in the evening.
    uint32_t colour = lightOverride[i] >= 0 ? (uint32_t)lightOverride[i]
                    : (reported & (1 << i)) ? strip.Color(90, 45, 12) : 0;
    for (int j = 0; j < LEDS_PER_SLOT; j++) strip.setPixelColor(i * LEDS_PER_SLOT + j, colour);
  }
  strip.show();
#endif
}

// ---------------------------------------------------------------- commands
// The commands are small and fixed, so they're read by looking for their
// fields rather than with a JSON library.

// The number after "key": in json, or -1.
long numberField(const std::string &json, const char *key) {
  std::string k = std::string("\"") + key + "\":";
  size_t at = json.find(k);
  return at == std::string::npos ? -1 : strtol(json.c_str() + at + k.size(), nullptr, 10);
}

// The string after "key":" in json, or "".
std::string stringField(const std::string &json, const char *key) {
  std::string k = std::string("\"") + key + "\":\"";
  size_t at = json.find(k);
  if (at == std::string::npos) return "";
  size_t from = at + k.size(), to = json.find('"', from);
  return to == std::string::npos ? "" : json.substr(from, to - from);
}

void command(const std::string &json) {
  std::string cmd = stringField(json, "cmd");
  if (cmd == "time") {
    long epoch = numberField(json, "epoch");
    if (epoch > 0) epochAtBoot = (uint32_t)epoch - millis() / 1000;
  } else if (cmd == "ping") {
    char out[48];
    snprintf(out, sizeof out, "{\"v\":%d,\"event\":\"pong\"}", PROTOCOL);
    send(out);
  } else if (cmd == "light") {
    long slot = numberField(json, "slot");
    if (slot < 1 || slot > SLOTS) return;
    std::string rgb = stringField(json, "rgb");
    lightOverride[slot - 1] = rgb == "auto" || rgb.size() != 6 ? -1 : strtol(rgb.c_str(), nullptr, 16);
    light();
  }
}

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *c, NimBLEConnInfo &info) override {
    command(c->getValue());
  }
};

// ---------------------------------------------------------------- slots

// Slots filled from the USB cable, for testing on a desk with no sensors
// wired: send 1–4 to toggle that slot, 0 to empty them all. A box in a drawer
// has nothing on the other end of its USB, so this never fires there.
uint8_t pretend = 0;

void readSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c >= '1' && c < '1' + SLOTS) pretend ^= (1 << (c - '1'));
    else if (c == '0') pretend = 0;
  }
}

// The INA219's shunt voltage register, as a number of 10 µV steps; 0 if it
// doesn't answer, which reads as an empty slot rather than a stuck one.
int16_t shuntSteps(int address) {
  Wire.beginTransmission(address);
  Wire.write(0x01);
  if (Wire.endTransmission() != 0 || Wire.requestFrom(address, 2) != 2) return 0;
  return (int16_t)((Wire.read() << 8) | Wire.read());
}

float milliamps[SLOTS][AVERAGE_OVER];
int sample = 0;
unsigned long sampledAt = 0;
uint8_t drawing = 0;              // the current sensors' verdict, a bit per slot

void sampleCurrent() {
  if (millis() - sampledAt < 100) return;
  sampledAt = millis();
  sample = (sample + 1) % AVERAGE_OVER;
  for (int i = 0; i < SLOTS; i++) {
    if (SLOT_INA219[i] < 0) continue;
    milliamps[i][sample] = shuntSteps(SLOT_INA219[i]) * MA_PER_STEP;
    float sum = 0;
    for (int j = 0; j < AVERAGE_OVER; j++) sum += milliamps[i][j];
    float average = sum / AVERAGE_OVER;
    if (average >= IN_MA) drawing |= (1 << i);
    else if (average < OUT_MA) drawing &= ~(1 << i);
  }
}

uint8_t readSlots() {
  uint8_t bits = pretend | drawing;
  for (int i = 0; i < SLOTS; i++) {
    if (SLOT_PINS[i] >= 0 && digitalRead(SLOT_PINS[i]) == SLOT_ACTIVE) bits |= (1 << i);
  }
  return bits;
}

void publishState() {
  uint8_t state[SLOTS];
  for (int i = 0; i < SLOTS; i++) state[i] = (reported & (1 << i)) ? CHARGING : EMPTY;
  slotStateChar->setValue(state, SLOTS);
}

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < SLOTS; i++) if (SLOT_PINS[i] >= 0) pinMode(SLOT_PINS[i], INPUT_PULLUP);
  Wire.begin(I2C_SDA, I2C_SCL);
#if LIGHT_PIN >= 0
  strip.begin();
#endif

  NimBLEDevice::init("");
  // Portside-XXXX, the last two bytes of the radio's address, so two boxes in
  // one house can be told apart in a scanner. Phones find the box by its
  // service, never its name.
  const uint8_t *mac = NimBLEDevice::getAddress().getVal();
  char name[16];
  snprintf(name, sizeof name, "Portside-%02X%02X", mac[1], mac[0]);
  NimBLEDevice::setDeviceName(name);

  NimBLEServer *server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  NimBLEService *service = server->createService(SERVICE_UUID);
  slotStateChar = service->createCharacteristic(SLOT_STATE_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  eventChar = service->createCharacteristic(EVENT_UUID, NIMBLE_PROPERTY::NOTIFY);
  service->createCharacteristic(COMMAND_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR)
         ->setCallbacks(new CommandCallbacks());

  reported = seen = readSlots();
  seenSince = millis();
  publishState();
  light();
  // In NimBLE 2.x the server starts its services; advertising would start it
  // anyway, but saying so here keeps the order readable.
  server->start();

  // The service id fills most of an advertisement's 31 bytes, so the name
  // goes in the scan response.
  NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  NimBLEAdvertisementData response;
  response.setName(name);
  advertising->setScanResponseData(response);
  advertising->start();
  Serial.printf("%s up, slots %02x\n", name, reported);
}

void loop() {
  readSerial();
  sampleCurrent();
  uint8_t sensed = readSlots();
  if (sensed != seen) {
    seen = sensed;
    seenSince = millis();
  }
  if (seen != reported && millis() - seenSince >= SETTLE_MS) {
    uint8_t changed = seen ^ reported;
    reported = seen;
    light();
    publishState();
    slotStateChar->notify();
    // One event per slot that changed, after the state they add up to.
    for (int i = 0; i < SLOTS; i++) {
      if (!(changed & (1 << i))) continue;
      char out[96];
      snprintf(out, sizeof out, "{\"v\":%d,\"slot\":%d,\"event\":\"%s\",\"t\":%lu}",
               PROTOCOL, i + 1, (reported & (1 << i)) ? "docked" : "undocked", (unsigned long)now());
      send(out);
    }
  }
  delay(20);
}
