import 'package:flutter/material.dart';

/// Identifies each tool slot so [ToolColors] can derive
/// the correct hue-shifted color from the active theme.
enum ToolColorKey {
  merge,
  split,
  protect,
  unlock,
  imgToPdf,
  pdfToImg,
  compress,
  sign,
  convertTxt,
  convertCsv,
  convertDocx,
  convertXlsx,
  convertPptx,
}

/// Derives distinct, semantically meaningful colors from the active
/// theme primary so tool identity stays consistent across screens.
class ToolColors {
  final ColorScheme scheme;

  const ToolColors(this.scheme);

  HSLColor get _base => HSLColor.fromColor(scheme.primary);

  /// Returns a color at [hueDelta] degrees away from the theme primary.
  Color _shift(double hueDelta, {double satMul = 1.0}) {
    return HSLColor.fromAHSL(
      1.0,
      (_base.hue + hueDelta) % 360,
      (_base.saturation * satMul).clamp(0.55, 1.0),
      _base.lightness.clamp(0.40, 0.62),
    ).toColor();
  }

  // Organise
  Color get merge => scheme.primary; // blue
  Color get split => _shift(45); // violet

  // Security
  Color get protect => _shift(280); // green
  Color get unlock => _shift(180); // amber/orange

  // Convert (core)
  Color get imgToPdf => _shift(140); // red
  Color get pdfToImg => _shift(330); // cyan

  // Enhance
  Color get compress => _shift(170); // orange
  Color get sign => _shift(120); // pink

  // Convert (file formats)
  Color get convertTxt => _shift(20); // indigo-blue
  Color get convertCsv => _shift(285, satMul: 0.72); // green (muted)
  Color get convertDocx => _shift(0); // blue
  Color get convertXlsx => _shift(300, satMul: 0.68); // deeper green (muted)
  Color get convertPptx => _shift(160); // orange-red

  Color forKey(ToolColorKey key) {
    switch (key) {
      case ToolColorKey.merge:
        return merge;
      case ToolColorKey.split:
        return split;
      case ToolColorKey.protect:
        return protect;
      case ToolColorKey.unlock:
        return unlock;
      case ToolColorKey.imgToPdf:
        return imgToPdf;
      case ToolColorKey.pdfToImg:
        return pdfToImg;
      case ToolColorKey.compress:
        return compress;
      case ToolColorKey.sign:
        return sign;
      case ToolColorKey.convertTxt:
        return convertTxt;
      case ToolColorKey.convertCsv:
        return convertCsv;
      case ToolColorKey.convertDocx:
        return convertDocx;
      case ToolColorKey.convertXlsx:
        return convertXlsx;
      case ToolColorKey.convertPptx:
        return convertPptx;
    }
  }
}
