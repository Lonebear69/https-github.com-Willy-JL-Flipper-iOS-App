import Core
import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var device: Device
    @EnvironmentObject var central: Central
    @Environment(\.dismiss) private var dismiss

    @State private var showHelpSheet = false
    @State private var isCanceledOrInvalidPin = false
    @State private var lastUUID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            switch central.state {
            case .poweredOn:
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("Searching")
                        ProgressView()
                    }
                    .opacity(central.isScanTimeout ? 0 : 1)

                    alertsHack()

                    Spacer()

                    Button {
                        showHelpSheet = true
                    } label: {
                        HStack(spacing: 7) {
                            Text("Help")
                            Image(systemName: "questionmark.circle.fill")
                                .resizable()
                                .frame(width: 22, height: 22)
                        }
                    }
                    .foregroundColor(.black40)
                }
                .font(.system(size: 16, weight: .medium))
                .padding(.bottom, 32)
                .padding(.top, 74)

                if central.flippers.isEmpty {
                    if central.isScanTimeout {
                        ScanTimeoutView {
                            central.startScan()
                        }
                    } else {
                        ConnectPlaceholderView()
                            .padding(.bottom, 77)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 14) {
                            ForEach(central.flippers) { flipper in
                                ConnectionRow(
                                    flipper: flipper,
                                    isConnecting: central.isConnecting
                                ) {
                                    lastUUID = flipper.id
                                    central.connect(to: flipper.id)
                                }
                            }
                        }
                    }
                }
            case .unauthorized:
                BluetoothAccessView()
            default:
                BluetoothOffView()
            }

            Spacer()
            Button("Skip connection") {
                device.forgetDevice()
                router.hideWelcomeScreen()
            }
            .padding(.bottom, onMac ? 140 : 8)
            .disabled(central.isConnecting)
        }
        .padding(.horizontal, 16)
        .background(Color.background)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarColors(foreground: .primary, background: Color.background)
        .toolbar {
            LeadingToolbarItems {
                BackButton {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Connect your Flipper")
                    .font(.system(size: 22, weight: .bold))
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpView()
                .customBackground(Color.background)
        }
        .onAppear {
            if central.state == .poweredOn {
                central.startScan()
            } else {
                central.kick()
            }
        }
        .onDisappear {
            central.stopScan()
        }
        .onChange(of: central.state) { state in
            if state == .poweredOn {
                central.startScan()
            }
        }
        .onChange(of: device.status) { status in
            if status == .pairingFailed {
                isCanceledOrInvalidPin = true
            }
        }
    }
}

// TODO: Replace with new API on iOS15

extension ConnectionView {
    func alertsHack() -> some View {
        HStack {
            Spacer()
                .alert(isPresented: $central.isConnectTimeout) {
                    .connectionTimeout {
                        central.stopScan()
                        central.startScan()
                    }
                }
            Spacer()
                .alert(isPresented: $isCanceledOrInvalidPin) {
                    .canceledOrIncorrectPin {
                        if let uuid = lastUUID {
                            central.connect(to: uuid)
                        }
                    }
                }
        }
    }
}
