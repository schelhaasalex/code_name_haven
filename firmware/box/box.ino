// The box: four slots, a sensor under each, and a Bluetooth radio that tells
// the phones connected to it when a slot fills or empties.
//
// The phone does the rest. Each one connected hears the change, and the one
// that just started charging, with this radio right beside it, starts its
// evening (ReclaimKit/Dock/Box.swift has the same ids and the same byte).
//
// Board: any ESP32 with Bluetooth LE — an ESP32-C3 or ESP32-S3 dev board, a
// Seeed XIAO ESP32-C3/S3. Not an ESP32-S2: it has no Bluetooth.
// Library: NimBLE-Arduino 1.4.x (the 2.x API is different). Optional:
// Adafruit NeoPixel, for lights the box runs itself.
//
// docs/DOCK.md has the wiring, and how to flash it.

#include <NimBLEDevice.h>

// ---------------------------------------------------------------- this box
// From scripts/dock-tags.sh, which prints it beside the four tag links. The
// first eight bytes of SHA-256 of the box's secret: who the box is, never the
// secret itself.
const char *BOX_ID_HEX = "0000000000000000";

// ---------------------------------------------------------------- wiring
// One digital input per slot. An IR obstacle module (FC-51 and the like)
// pulls its output LOW when something is over it; so does a switch wired to
// ground. Set SLOT_ACTIVE to HIGH for a sensor that does the opposite.
const int SLOT_PINS[4] = {2, 3, 4, 5};
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
class Callbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server) { NimBLEDevice::startAdvertising(); }
  void onDisconnect(NimBLEServer *server) { NimBLEDevice::startAdvertising(); }
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
  service->start();

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
