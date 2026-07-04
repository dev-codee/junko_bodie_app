enum GamePhase {
  betting, // Players can place and remove chips
  locked, // Betting closed, spin is about to begin
  spinning, // Wheel is in motion, no interaction allowed
  result, // Result is displayed, win/loss calculated
  reset // Table clears, next round begins
}
