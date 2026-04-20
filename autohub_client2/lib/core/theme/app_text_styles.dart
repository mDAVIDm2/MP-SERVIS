import 'package:flutter/material.dart';
import 'client_palette.dart';

/// Типографика с учётом темы: передавайте [ClientPalette] из `context.palette`.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle sectionTitle(ClientPalette p) => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: p.gold1,
        letterSpacing: -0.5,
      );

  static TextStyle serviceTitle(ClientPalette p) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle orderNumber(ClientPalette p) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.gold1,
        letterSpacing: -0.2,
      );

  static TextStyle bodySecondary(ClientPalette p) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: p.textSecondary,
      );

  static TextStyle price(ClientPalette p) => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: p.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle screenTitle(ClientPalette p) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle cardTitle(ClientPalette p) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      );

  static TextStyle body(ClientPalette p) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: p.textPrimary,
      );

  static TextStyle small(ClientPalette p) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: p.textSecondary,
      );

  static TextStyle caption(ClientPalette p) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: p.textMuted,
      );

  static TextStyle numberLarge(ClientPalette p) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle numberSmall(ClientPalette p) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: p.textPrimary,
      );

  static TextStyle button(ClientPalette p) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.gold1,
      );

  static TextStyle chip(ClientPalette p) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      );

  static TextStyle carModelTitle(ClientPalette p) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
        letterSpacing: -0.5,
        height: 1.1,
      );

  static TextStyle stoTitle(ClientPalette p) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle accentSmall(ClientPalette p) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: p.gold1,
      );

  static TextStyle accentBody(ClientPalette p) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: p.gold1,
      );

  static TextStyle accentButton(ClientPalette p) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: p.gold1,
      );
}
