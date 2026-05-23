//
//  ContentView.swift
//  SlipBoard
//
//  Created by huynq3 on 5/17/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isAnimated = false
    
    var body: some View {
        ZStack {
            // Elegant dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Decorative background glowing gradients
            VStack {
                HStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: -50, y: -50)
                    Spacer()
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: 50, y: 50)
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            // Main Content Container
            VStack(spacing: 28) {
                // Header Group
                VStack(spacing: 8) {
                    // Logo/App Icon Placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 4)
                        
                        Image(systemName: "paperclip")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(isAnimated ? 360 : 0))
                            .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: isAnimated)
                    }
                    
                    Text("SlipBoard")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Phase 0: Bootstrap Restored")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .scaleEffect(isAnimated ? 1.0 : 0.95)
                .opacity(isAnimated ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5), value: isAnimated)
                
                // Status Dashboard (Glassmorphic)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Compilation Restored")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("The Swift compiler path is fully validated.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Awaiting App Shell Design")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Text("SB-BOOT-002: App Shell spec pending approval.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(24)
                .frame(width: 420)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.03))
                        .background(
                            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                                .opacity(0.4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                .offset(y: isAnimated ? 0 : 20)
                .opacity(isAnimated ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.15), value: isAnimated)
                
                // Active Features Placeholder List
                VStack(alignment: .leading, spacing: 12) {
                    Text("SYSTEM MODULES")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.gray.opacity(0.8))
                        .padding(.leading, 8)
                    
                    VStack(spacing: 8) {
                        ModuleRow(title: "Clipboard Capture", icon: "arrow.right.doc.on.clipboard", status: "Locked")
                        ModuleRow(title: "Popup Grid", icon: "rectangle.grid.3x2", status: "Locked")
                        ModuleRow(title: "Organization & Search", icon: "magnifyingglass", status: "Locked")
                    }
                }
                .frame(width: 420)
                .offset(y: isAnimated ? 0 : 20)
                .opacity(isAnimated ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: isAnimated)
            }
            .padding()
        }
        .onAppear {
            isAnimated = true
        }
    }
}

// Module Row View for modular layout
struct ModuleRow: View {
    let title: String
    let icon: String
    let status: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)
            Text(title)
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
            Spacer()
            Text(status)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// Visual Effect Blur helper for macOS natively
#if os(macOS)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
#else
struct VisualEffectBlur: View {
    var material: UIBlurEffect.Style
    var blendingMode: Int = 0 // Dummy parameter for iOS/Preview fallback
    
    var body: some View {
        Spacer()
    }
}
#endif

#Preview {
    ContentView()
        .frame(width: 1280, height: 820)
}
