// The box: four slots, a sensor under each, and a Bluetooth radio that tells
// the phones connected to it when a slot fills or empties.
//
// The phone does the rest. Each one connected hears the change, and the one
// that just started charging, with this radio right beside it, starts its
// evening (ReclaimKit/Dock/Box.swift has the same ids and the same byte).
//
// Board: any ESP32 with Bluetooth LE — an ESP32-C3 or ESP32-S3 dev board, a
// Seeed XIAO ESP32-C3/S3. Not an ESP32-S2: it has no Bluetooth.
// Library: NimBLE-Arduino 2.x (checked against 2.5.1). Optional: Adafruit
// NeoPixel, for lights the box runs itself.
//
// docs/DOCK.md has the wiring, and how to flash it.

#include <NimBLEDevice.h>

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

// ---------------------------------------------------------------- this box
// From scripts/dock-tags.sh, which prints it beside the four tag links. The
// first eight bytes of SHA-256 of the box's secret: who the box is, never the
// secret itself.
const char *BOX_ID_HEX = "0000000000000000";

// ---------------------------------------------------------------- wiring
// One digital input per slot. An IR obstacle module (FC-51 and the like)
// pulls its output LOW when something is over it; so does a switch wired to
// ground. Set SLOT_ACTIVE to HIGH for a sensor that does the opposite.
//
// GPIO numbers, not the board's labels. On a XIAO ESP32-C3 these are D1–D4.
// Not D0 (GPIO 2), D8 or D9: the chip reads those while it boots, and a phone
// sitting in that slot at power-on could stop it starting.
const int SLOT_PINS[4] = {3, 4, 5, 6};
const int SLOT_ACTIVE = LOW;

// The lights, if this board runs them: a strip with two LEDs per slot, slot 1
// first. -1 leaves the lights to something else (the WLED controller).
#define LIGHT_PIN -1
const int LEDS_PER_SLOT = 2;

// ---------------------------------------------------------------- the same ids as Box.swift
#define SERVICE_UUID "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C40"
#define ID_UUID      "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C41"
#define SLOTS_UUID   "3F1C5B2E-8D4A-4E6B-9C2F-0A7D1E5B8C42"

// A phone being slid in rocks a sensor on and off; a slot has to say the same
// thing for this long before it counts.
const unsigned long SETTLE_MS = 400;

#if LIGHT_PIN >= 0
#include <Adafruit_NeoPixel.h>
Adafruit_NeoPixel strip(4 * LEDS_PER_SLOT, LIGHT_PIN, NEO_GRB + NEO_KHZ800);
#endif

NimBLECharacteristic *slotsChar;
uint8_t reported = 0;            // what the phones were last told
uint8_t seen = 0;                // what the sensors say right now
unsigned long seenSince = 0;

// Every phone in the house stays connected, so as each one connects the box
// has to go straight back to advertising for the next.
//
// `override` on both, deliberately. NimBLE-Arduino changed these signatures
// between 1.4 and 2.x; without it, a sketch written for the other version
// compiles cleanly and the callbacks are simply never called — a box that
// takes one phone and then goes quiet.
class Callbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &info) override {
    NimBLEDevice::startAdvertising();
  }
  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &info, int reason) override {
    NimBLEDevice::startAdvertising();
  }
};

uint8_t readSlots() {
  uint8_t bits = 0;
  for (int i = 0; i < 4; i++) {
    if (digitalRead(SLOT_PINS[i]) == SLOT_ACTIVE) bits |= (1 << i);
  }
  return bits;
}

void light(uint8_t bits) {
#if LIGHT_PIN >= 0
  for (int i = 0; i < 4; i++) {
    // Warm, and low: it sits in a room in the evening.
    uint32_t colour = (bits & (1 << i)) ? strip.Color(90, 45, 12) : 0;
    for (int j = 0; j < LEDS_PER_SLOT; j++) strip.setPixelColor(i * LEDS_PER_SLOT + j, colour);
  }
  strip.show();
#endif
}

void setup() {
  Serial.begin(115200);
  for (int i = 0; i < 4; i++) pinMode(SLOT_PINS[i], INPUT_PULLUP);
#if LIGHT_PIN >= 0
  strip.begin();
#endif

  uint8_t id[8];
  for (int i = 0; i < 8; i++) {
    char byteHex[3] = {BOX_ID_HEX[i * 2], BOX_ID_HEX[i * 2 + 1], 0};
    id[i] = (uint8_t)strtoul(byteHex, nullptr, 16);
  }

  NimBLEDevice::init("Box");
  NimBLEServer *server = NimBLEDevice::createServer();
  server->setCallbacks(new Callbacks());
  NimBLEService *service = server->createService(SERVICE_UUID);
  service->createCharacteristic(ID_UUID, NIMBLE_PROPERTY::READ)->setValue(id, 8);
  slotsChar = service->createCharacteristic(SLOTS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  reported = seen = readSlots();
  seenSince = millis();
  slotsChar->setValue(&reported, 1);
  light(reported);
  // In NimBLE 2.x the server starts its services; advertising would start it
  // anyway, but saying so here keeps the order readable.
  server->start();

  NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->start();
  Serial.printf("box %s up, slots %02x\n", BOX_ID_HEX, reported);
}

void loop() {
  uint8_t now = readSlots();
  if (now != seen) {
    seen = now;
    seenSince = millis();
  }
  if (seen != reported && millis() - seenSince >= SETTLE_MS) {
    reported = seen;
    light(reported);
    slotsChar->setValue(&reported, 1);
    slotsChar->notify();
    Serial.printf("slots %02x\n", reported);
  }
  delay(20);
}
