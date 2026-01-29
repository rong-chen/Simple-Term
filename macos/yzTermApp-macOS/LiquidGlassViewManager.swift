//
//  LiquidGlassViewManager.swift
//  yzTermApp-macOS
//
//  液态玻璃效果视图管理器
//  使用 NSVisualEffectView 实现 macOS 原生毛玻璃/液态玻璃效果
//

import AppKit
import React

@objc(LiquidGlassViewManager)
class LiquidGlassViewManager: RCTViewManager {
  
  override func view() -> NSView! {
    return LiquidGlassView()
  }
  
  override static func requiresMainQueueSetup() -> Bool {
    return true
  }
}

class LiquidGlassView: NSVisualEffectView {
  
  private var _blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
  private var _material: NSVisualEffectView.Material = .hudWindow
  private var _state: NSVisualEffectView.State = .active
  private var _cornerRadius: CGFloat = 0
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupView()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }
  
  private func setupView() {
    self.wantsLayer = true
    self.blendingMode = _blendingMode
    self.material = _material
    self.state = _state
    self.layer?.cornerRadius = _cornerRadius
    self.layer?.masksToBounds = true
  }
  
  // MARK: - React Native Props
  
  @objc var blendMode: String = "behindWindow" {
    didSet {
      switch blendMode {
      case "withinWindow":
        _blendingMode = .withinWindow
      case "behindWindow":
        _blendingMode = .behindWindow
      default:
        _blendingMode = .behindWindow
      }
      self.blendingMode = _blendingMode
    }
  }
  
  @objc var materialType: String = "hudWindow" {
    didSet {
      switch materialType {
      case "titlebar":
        _material = .titlebar
      case "selection":
        _material = .selection
      case "menu":
        _material = .menu
      case "popover":
        _material = .popover
      case "sidebar":
        _material = .sidebar
      case "headerView":
        _material = .headerView
      case "sheet":
        _material = .sheet
      case "windowBackground":
        _material = .windowBackground
      case "hudWindow":
        _material = .hudWindow
      case "fullScreenUI":
        _material = .fullScreenUI
      case "toolTip":
        _material = .toolTip
      case "contentBackground":
        _material = .contentBackground
      case "underWindowBackground":
        _material = .underWindowBackground
      case "underPageBackground":
        _material = .underPageBackground
      default:
        _material = .hudWindow
      }
      self.material = _material
    }
  }
  
  @objc var effectState: String = "active" {
    didSet {
      switch effectState {
      case "active":
        _state = .active
      case "inactive":
        _state = .inactive
      case "followsWindowActiveState":
        _state = .followsWindowActiveState
      default:
        _state = .active
      }
      self.state = _state
    }
  }
  
  @objc var borderRadius: CGFloat = 0 {
    didSet {
      _cornerRadius = borderRadius
      self.layer?.cornerRadius = _cornerRadius
    }
  }
}
