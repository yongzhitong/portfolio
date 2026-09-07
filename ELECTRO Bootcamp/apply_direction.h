// ============================================================
// STUDENT FILE — implement motor direction control here
//
// This function is called whenever a direction button is pressed
// (or released) on the website.
//
// Available directions (Dir d):
//   UP, DOWN, LEFT, RIGHT, NONE
//
// Motor driver pins (already defined in electro_bootcamp.ino):
//   AIN1, AIN2  — Motor A direction
//   BIN1, BIN2  — Motor B direction
//
// Tip: for NONE, set all four pins LOW to stop.
// ============================================================

#pragma once

void applyDirection(Dir d) {
  currentDir = d;

  if (d == UP) {
    digitalWrite(AIN2, HIGH);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, HIGH);
  } else if (d == DOWN) {
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, HIGH);
    digitalWrite(BIN2, HIGH);
    digitalWrite(BIN1, LOW);
  } else if (d == LEFT) {
    digitalWrite(AIN2, HIGH);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, HIGH);
    digitalWrite(BIN1, LOW);
  } else if (d == RIGHT) {
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, HIGH);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, HIGH);
  } else {
    // NONE: stop both sides
    digitalWrite(AIN2, LOW);
    digitalWrite(AIN1, LOW);
    digitalWrite(BIN2, LOW);
    digitalWrite(BIN1, LOW);
  }
}
