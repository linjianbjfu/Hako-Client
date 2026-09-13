import HakoClientUI
import SwiftUI

enum ProxyShareEndpointFormatter {
    static func format(address: String, port: Int32) -> String {
        address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"
    }
}

struct ProxyShareView: View {
    @ObservedObject var model: ProxyShareModel
    var showsVPNSharing = false

     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var deviations: ConfigDeviationReport?
    @AppStorage(ProxyEnvironmentShell.defaultsKey) private var environmentShellRaw = ProxyEnvironmentShell.bash.rawValue
    @State private var environmentCopied: EnvironmentCopy?

    private enum EnvironmentCopy {
        case local
        case external
    }
    @State private var portText = ""
    @State private var username = ""
    @State private var password = ""
    @State private var confirmsReset = false
     
     
    @State private var lanExposureNotices: [String] = []
     
     
     
    #if os(macOS)
    @State private var tab: LANShareTab = .native
    #else
    @State private var tab: LANShareTab = .core
    #endif

    enum LANShareTab: Hashable {
        case core
        case native
    }

    var body: some View {
         
         
         
         
         
         
         
        VStack(spacing: 0) {
            #if !os(macOS)
            tabPickerBar
            #endif
            HakoMacSettingsFormContainer {
                switch visibleTab {
                case .core:
                    coreSwitchSection
                     
                     
                     
                    if kernelShare.isOn, let listener = kernelShare.listener {
                        coreListenerSection(listener)
                        coreConnectSection(listener)
                    }
                    if model.terminalListener != nil {
                        terminalSection
                    }
                    coreExposureSection
                    listenerDeviationsSection
                case .native:
                     
                     
                     
                     
                     
                     
                    actionSection
                    if model.status.enabled {
                        connectSection
                    }
                    serverSection
                    securitySection
                    #if os(macOS)
                    Section {
                        HakoRoutedViewLink {
                            ProxyShareView(model: model, showsVPNSharing: true)
                        } label: {
                            Text("VPN LAN Sharing")
                        }
                    }
                    #endif
                    if model.terminalListener != nil {
                        terminalSection
                    }
                }
            }
        }
        .hakoPageTitle(.copy(pageTitle))
        .hakoDetailPageInsets()
        .task {
            hydrateDraft(overwriteUsername: true)
             
             
             
             
             
            lanExposureNotices = CoreLogExcerpt.lanExposureNotices()
            deviations = await Task.detached(priority: .utility) {
                RunningCoreDeviations.activeProfileReport()
            }.value
            await model.refresh()
            hydrateDraft(overwriteUsername: username.isEmpty)
        }
        .refreshable {
            await model.refresh()
            hydrateDraft(overwriteUsername: username.isEmpty)
        }
        .onChange(of: model.rememberedPort) { _ in
            if !isEditingPort { portText = String(model.rememberedPort) }
        }
         
         
         
         
         
        .onChange(of: tab) { _ in
            hydrateDraft(overwriteUsername: false)
        }
        .onReceive(model.terminalListenerDidChange) { _ in
            hydrateDraft(overwriteUsername: false)
        }
        .confirmationDialog(
            "Reset LAN proxy credentials?",
            isPresented: $confirmsReset,
            titleVisibility: .visible
        ) {
            Button("Reset Credentials", role: .destructive) {
                Task {
                    if await model.reset() {
                        password = ""
                        hydrateDraft(overwriteUsername: true)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sharing stops first. The saved username and password are then removed from this device.")
        }
    }

    private var visibleTab: LANShareTab {
        #if os(macOS)
        showsVPNSharing ? .core : .native
        #else
        tab
        #endif
    }

    private var pageTitle: String {
        #if os(macOS)
        showsVPNSharing ? "VPN LAN Sharing" : "Independent Proxy"
        #else
        "LAN Proxy Share"
        #endif
    }

    private var actionSection: some View {
        Section {
             
             
             
             
             
            #if os(macOS)
            Toggle("Enable Independent Proxy", isOn: Binding(
                get: { model.independentEnabled },
                set: { enabled in
                    Task {
                        if enabled { await submit() }
                        else { _ = await model.stop() }
                    }
                }
            ))
            .disabled(model.phase.isBusy)
            .accessibilityIdentifier("proxyShare.toggle")
            .accessibilityValue(model.phase.title)
            OverviewValueRow(title: "Status", value: .copy(model.phase.title))
            if model.independentEnabled, !model.status.enabled, !model.phase.isBusy {
                Button("Retry") { Task { await model.startSavedIndependentServer() } }
            }
            #else
            Button {
                Task {
                    if model.status.enabled {
                        _ = await model.stop()
                    } else {
                        await submit()
                    }
                }
            } label: {
                 
                 
                 
                 
                 
                Text(model.status.enabled ? "Stop Sharing" : "Start Sharing")
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .hakoPrimaryActionButtonStyle()
            .hakoCapsuleButtonBorderShape()
            .controlSize(.regular)
            .tint(model.status.enabled ? .green : .blue)
            .disabled(model.phase == .unavailable || model.phase.isBusy)
            .accessibilityIdentifier("proxyShare.toggle")
            .accessibilityValue(model.phase.title)

            #endif

            if model.phase.isBusy {
                HStack(spacing: HakoTheme.Spacing.row) {
                    ProgressView()
                    Text(model.phase.title)
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if !model.errorMessage.isEmpty {
                HakoStatusMessage(text: .copy(model.errorMessage), kind: .error)
                    .accessibilityIdentifier("proxyShare.error")
            }
        } footer: {
            Text(hako: .copy(actionExplanation))
        }
    }

    private var connectSection: some View {
        Section {
            #if os(macOS)
            OverviewValueRow(title: "This Mac", value: .verbatim("127.0.0.1:\(model.status.port)"))
            #endif
            if reachableAddresses.isEmpty {
                HakoStatusMessage(
                    text: .copy("No usable Wi-Fi or Personal Hotspot address is available."),
                    kind: .information
                )
            } else {
                ForEach(reachableAddresses, id: \.self) { address in
                    Text(ProxyShareEndpointFormatter.format(
                        address: address,
                        port: model.status.port
                    ))
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .subheadline.monospaced())
                    .textSelection(.enabled)
                     
                     
                     
                     
                    .id("share:\(address)")
                }
            }
            if model.status.authenticationRequired {
                OverviewValueRow(title: "Username", value: .verbatim(model.savedUsername))
            } else {
                OverviewValueRow(title: "Authentication", value: .copy("Not Required"))
            }
        } header: {
            #if os(macOS)
            Text("Proxy Addresses")
            #else
            Text("Connect From Another Device")
            #endif
        } footer: {
            if model.status.authenticationRequired {
                Text("Point the other device at one address above, over HTTP or SOCKS5, with this username and its saved password.")
            } else {
                Text("Connect over HTTP or SOCKS5 using an address above. No username or password is required.")
            }
        }
    }

    private var serverSection: some View {
        Section {
             
             
             
             
             
            HakoFieldRow(
                "Port",
                hint: "7890",
                text: $portText,
                monospaced: true,
                identifier: "proxyShare.port"
            )
            .keyboardType(.numberPad)
            .disabled(inputsDisabled)

            HakoFieldRow(
                "Username",
                hint: model.allowsUnauthenticated ? "Optional" : "Required",
                text: $username,
                identifier: "proxyShare.username"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(inputsDisabled)

             
             
             
            HakoFieldRow(
                "Password",
                hint: model.allowsUnauthenticated ? "Optional" : ProxyShareCredentialPolicy.passwordByteRangeDescription,
                text: $password,
                secure: true,
                identifier: "proxyShare.password"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .disabled(inputsDisabled)
        } header: {
            Text("Server")
        } footer: {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                 
                 
                 
                if !model.status.enabled, model.nativeSharePortSuggestion != nil {
                    Text(hako: .format(
                        "Port %@ is the profile's listener, so the next free port is suggested.",
                        [String(model.rememberedPort)]
                    ))
                    .accessibilityIdentifier("proxyShare.port.taken")
                }
                Text(hako: .copy(serverExplanation))
            }
        }
    }

    private var securitySection: some View {
        Section {
             
             
             
             
             
            Button(role: .destructive) {
                confirmsReset = true
            } label: {
                Text("Reset Saved Credentials")
            }
             
             
            .hakoMacFormActionChrome()
            .disabled(model.phase.isBusy || (!model.hasSavedPassword && !model.independentRequiresAuthentication))
            .accessibilityIdentifier("proxyShare.reset")
        } header: {
            Text("Security")
        } footer: {
             
             
            #if os(macOS)
            Text("This Mac and local network devices can connect. Closing the window keeps the proxy running; quitting Clash stops it. Credentials are kept out of profiles and backups.")
            #else
            Text("Only private, unique-local, and link-local source addresses are accepted. Sharing closes when the VPN stops, and credentials never enter profiles, backups, logs, or diagnostics.")
            #endif
        }
    }

    private var kernelShare: KernelLANShare { model.kernelShare }

     
     
     
     
     
    private var tabPickerBar: some View {
#if os(macOS)
        HStack(spacing: 2) {
            tabSegment(.core, "Core", identifier: "proxyShare.tab.core")
            tabSegment(.native, "Proxy Server", identifier: "proxyShare.tab.native")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
#else
        Picker(HakoCopy.key("Listener"), selection: $tab) {
            Text(HakoCopy.key("Core")).tag(LANShareTab.core)
            Text(HakoCopy.key("Native Share")).tag(LANShareTab.native)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("proxyShare.tab")
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
#endif
    }

#if os(macOS)
    private func tabSegment(
        _ target: LANShareTab,
        _ key: String,
         
         
        identifier: String
    ) -> some View {
        Button {
            tab = target
        } label: {
            Text(HakoCopy.key(key))
                .font(.callout.weight(tab == target ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if tab == target {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlColor))
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(tab == target ? .isSelected : [])
    }
#endif

     
     
     
     
     
     
     
    private var coreSwitchSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { kernelShare.isOn },
                set: { on in Task { await model.setKernelShare(on: on) } }
            )) {
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    Text("Share on the Local Network")
                    Text(hako: .copy(kernelShareSourceLine))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("proxyShare.allowLan.source")
                }
            }
            .accessibilityIdentifier("proxyShare.allowLan")

            if !model.errorMessage.isEmpty {
                HakoStatusMessage(text: .copy(model.errorMessage), kind: .error)
                    .accessibilityIdentifier("proxyShare.error")
            }
        } footer: {
            Text("This is the profile's allow-lan. Written in the profile, it is read as written; not written, turning this on writes an override. Takes effect the next time the tunnel starts.")
        }
    }

     
     
     
     
     
     
     
     
    @ViewBuilder
    private var coreExposureSection: some View {
        if !lanExposureNotices.isEmpty {
            Section {
                ForEach(lanExposureNotices, id: \.self) { notice in
                    Label {
                        Text(hako: .verbatim(notice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: HakoSymbol.exclamationmarkTriangleFill.rawValue)
                            .foregroundStyle(Color.orange)
                    }
                    .accessibilityIdentifier("proxyShare.lanExposure")
                }
            } header: {
                Text("Last Start")
            }
        }
    }

     
     
     
    private var kernelShareSourceLine: String {
        kernelShare.source == .override ? "Override" : "From the profile"
    }

     
     
     
     
     
     
     
    private func coreListenerSection(_ listener: ProfileListenerPorts) -> some View {
        Section {
            if let mixed = listener.mixedPort {
                OverviewValueRow(title: "Port", value: .verbatim(String(mixed)))
                    .accessibilityIdentifier("proxyShare.listener.port")
                OverviewValueRow(title: "Protocols", value: .copy("HTTP + SOCKS5"))
                    .accessibilityIdentifier("proxyShare.listener.protocols")
            } else {
                if let http = listener.httpPort {
                    OverviewValueRow(title: "HTTP Port", value: .verbatim(String(http)))
                        .accessibilityIdentifier("proxyShare.listener.port")
                }
                if let socks = listener.socksPort {
                    OverviewValueRow(title: "SOCKS5 Port", value: .verbatim(String(socks)))
                        .accessibilityIdentifier("proxyShare.listener.port")
                }
            }
            OverviewValueRow(
                title: "Authentication",
                value: listener.credentials.map { .verbatim($0.username) } ?? .copy("Not set")
            )
            .accessibilityIdentifier("proxyShare.listener.authentication")
        } header: {
            Text("Listener")
        } footer: {
            Text(hako: .copy(
                listener.credentials == nil
                    ? "The profile sets no authentication: anyone on this network can use this proxy."
                    : "Credentials come from the profile's authentication."
            ))
        }
    }

     
     
    private func coreConnectSection(_ listener: ProfileListenerPorts) -> some View {
        let ports = listener.mixedPort.map { [$0] }
            ?? [listener.httpPort, listener.socksPort].compactMap { $0 }
        return Section {
            if reachableAddresses.isEmpty {
                HakoStatusMessage(
                    text: .copy("No usable Wi-Fi or Personal Hotspot address is available."),
                    kind: .information
                )
            } else {
                ForEach(reachableAddresses, id: \.self) { address in
                    ForEach(ports, id: \.self) { port in
                        Text(ProxyShareEndpointFormatter.format(address: address, port: port))
                            .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .subheadline.monospaced())
                            .textSelection(.enabled)
                             
                             
                            .id("core:\(address):\(port)")
                    }
                }
            }
        } header: {
            Text("Connect From Another Device")
        } footer: {
            Text("Point the other device at one address above, over HTTP or SOCKS5.")
        }
    }

     
     
     
     
    private var listenerDeviationsSection: some View {
        ConfigDeviationSection(
            report: deviations,
            fields: RunningCoreDeviations.fields(for: [.localProxyListeners]),
            identifierPrefix: "proxyShare.deviation"
        )
    }

     
     
    private var reachableAddresses: [String] {
        model.reachableAddresses
    }

     
     
     
     
     
     
     
     
     
     
    private var terminalSection: some View {
        Section {
            Picker("Shell", selection: environmentShell) {
                ForEach(ProxyEnvironmentShell.allCases) { shell in
                    Text(verbatim: shell.title).tag(shell)
                }
            }
            .accessibilityIdentifier("proxyShare.environment.shell")
            HStack {
                Text("Environment Variables")
                Spacer()
                Button(action: { copyEnvironment(externalIP: false) }) {
                    if environmentCopied == .local {
                        Text("Copied")
                    } else {
                        Text("Copy")
                    }
                }
                .disabled(model.phase.isBusy || !localLineIsAvailable)
                .accessibilityIdentifier("proxyShare.environment.copy")
#if os(macOS)
                Button(action: { copyEnvironment(externalIP: true) }) {
                    if environmentCopied == .external {
                        Text("Copied")
                    } else {
                        Text("Copy (External IP)")
                    }
                }
                .disabled(model.phase.isBusy || !externalLineIsAvailable)
                .accessibilityIdentifier("proxyShare.environment.copy-external")
#endif
            }
        } header: {
            Text("Terminal")
        }
    }

     
     
    private var externalLineIsAvailable: Bool {
        guard let listener = model.terminalListener else { return false }
        return listener.host(forExternalMachine: true, addresses: reachableAddresses) != nil
    }

    private var localLineIsAvailable: Bool {
        guard let listener = model.terminalListener else { return false }
        return environmentHost(for: listener, externalIP: false) != nil
    }

    private var environmentShell: Binding<ProxyEnvironmentShell> {
        Binding(
            get: { ProxyEnvironmentShell(rawValue: environmentShellRaw) ?? .bash },
            set: { environmentShellRaw = $0.rawValue }
        )
    }

    private func environmentHost(for listener: ProxyTerminalListener, externalIP: Bool) -> String? {
#if os(macOS)
        listener.host(forExternalMachine: externalIP, addresses: reachableAddresses)
#else
        listener.host(forExternalMachine: true, addresses: reachableAddresses)
#endif
    }

    private func copyEnvironment(externalIP: Bool) {
        guard let listener = model.terminalListener else { return }
        guard let host = environmentHost(for: listener, externalIP: externalIP) else { return }
        let text = ProxyEnvironmentCommand.text(
            shell: environmentShell.wrappedValue,
            endpoint: ProxyEnvironmentEndpoint(
                host: host,
                httpPort: listener.httpPort,
                socksPort: listener.socksPort,
                username: listener.username,
                password: model.terminalPassword(for: listener)
            )
        )
#if canImport(UIKit)
         
         
        CredentialPasteboardWrite.put(text)
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
        environmentCopied = externalIP ? .external : .local
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            environmentCopied = nil
        }
    }

    private var actionExplanation: String {
        #if os(macOS)
        return "When enabled, the proxy listens automatically when Clash opens. It follows Global, Rule, or Direct in General and does not require the Home Start(VPN) button or a VPN."
        #else
        switch model.phase {
        case .unavailable:
            return "Connect Clash to make the authenticated local proxy available."
        case .failed:
            return "The last change was not confirmed. The Core status will be checked again when this page refreshes."
        case .running:
            return "The VPN stays connected while sharing runs."
        default:
            return "Starting may ask for Local Network access; Clash cannot accept nearby devices without it."
        }
        #endif
    }

    private var serverExplanation: String {
        if model.status.enabled || (model.allowsUnauthenticated && model.independentEnabled) {
            #if os(macOS)
            return "Turn off the independent proxy to change the port or credentials."
            #else
            return "Stop sharing to change the port or credentials."
            #endif
        }
        if model.allowsUnauthenticated {
            return "Leave both username and password empty to share without authentication. To require authentication, fill in both fields."
        }
         
         
         
        return "Both HTTP and SOCKS5 always require the same username and password. Enter the password each time you start sharing — you need to know it to type it into the other device."
    }

     
     
    private var inputsDisabled: Bool {
        model.phase == .unavailable
            || model.phase.isBusy
            || model.status.enabled
            || (model.allowsUnauthenticated && model.independentEnabled)
    }

    private var isEditingPort: Bool {
        portText != String(model.rememberedPort)
    }

    private func hydrateDraft(overwriteUsername: Bool) {
        if portText.isEmpty || !isEditingPort {
             
            portText = String(model.nativeSharePortSuggestion ?? model.rememberedPort)
        }
        if overwriteUsername {
            #if os(macOS)
            if !model.independentRequiresAuthentication {
                username = ""
                password = ""
            } else {
                username = model.savedUsername
                password = model.savedPassword() ?? ""
            }
            #else
            username = model.savedUsername
            #endif
        }
    }

    private func submit() async {
        let submittedPassword = password
        #if !os(macOS)
        password = ""
        #endif
        _ = await model.start(
            portText: portText,
            username: username,
            password: submittedPassword
        )
    }
}

struct OverviewMoreSettingsCard: View {
    @ObservedObject var proxyShare: ProxyShareModel

    private var overviewDetail: String {
        #if os(macOS)
        "HTTP and SOCKS5 without a VPN"
        #else
        "Authenticated HTTP and SOCKS5 for nearby devices"
        #endif
    }

    var body: some View {
        HakoOverviewCard {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                OverviewCardHeader(
                    title: "More Settings",
                    symbol: .gearshape,
                    tint: .blue
                )

                HakoRoutedViewLink {
                    ProxyShareView(model: proxyShare)
                } label: {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        HakoIconWell(symbol: .network, tint: .green)
                        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                            Text(HakoCopy.key(HakoUtilitiesDestination.proxyShare.title))
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(HakoCopy.key(overviewDetail))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        HakoStatusBadge(
                            title: proxyShare.phase == .running ? "On" : "Off",
                            tint: proxyShare.phase == .running ? .green : .gray
                        )
                        Image(systemName: HakoSymbol.chevronForward.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, HakoTheme.Spacing.tight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overview.moreSettings.proxyShare")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.card.moreSettings")
    }
}
