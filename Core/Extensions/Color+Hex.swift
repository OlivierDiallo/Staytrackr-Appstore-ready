//
//  Color+Hex.swift
//  StayTrackr V3
//
//  Created by Olivier Diallo on 06.01.2026.
//
import SwiftUI

extension Color {
  init(hex: String) {
    let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    let r = Double((v >> 16) & 0xFF) / 255
    let g = Double((v >> 8)  & 0xFF) / 255
    let b = Double(v & 0xFF)        / 255
    self.init(red: r, green: g, blue: b)
  }
}
