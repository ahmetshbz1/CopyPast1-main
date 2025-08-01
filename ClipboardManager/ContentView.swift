import SwiftUI

struct ContentView: View {
    @StateObject private var state = ContentViewState()
    @Environment(\.colorScheme) private var colorScheme
    
    private var actions: ContentViewActions {
        ContentViewActions(state: state)
    }
    
    private var components: ContentViewComponents {
        ContentViewComponents(state: state, actions: actions)
    }
    
    var body: some View {
        Group {
            if !state.onboardingManager.isOnboardingCompleted {
                OnboardingView(onboardingManager: state.onboardingManager)
            } else {
                mainContentView
            }
        }
        .onAppear {
            state.setupNotificationObserver()
        }
        .sheet(isPresented: $state.showAboutSheet) {
            AboutView(showAboutSheet: $state.showAboutSheet)
        }
    }
    
    private var mainContentView: some View {
        NavigationView {
            ZStack {
                AnimatedBackground()
                
                VStack(spacing: 0) {
                    if !state.clipboardManager.clipboardItems.isEmpty {
                        components.headerSection()
                    }
                    
                    components.contentSection()
                    
                    if state.showToast {
                        ToastView(message: state.toastMessage)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .offset(y: 10)
                    }
                }
            }
            .navigationTitle("Pano Geçmişi")
            .toolbar {
                toolbarContent
            }
            .onTapGesture {
                actions.dismissKeyboard()
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if !state.clipboardManager.clipboardItems.isEmpty {
                Button(action: state.clearAllItems) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(ToolbarButtonStyle())
            }
            
            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(ToolbarButtonStyle())
        }
    }
    
    @ViewBuilder
    private var menuContent: some View {
        Button(action: actions.resetOnboarding) {
            Label("Kurulum Sihirbazı", systemImage: "wand.and.stars")
        }
        
        Button(action: actions.openSettings) {
            Label("Klavye Ayarları", systemImage: "keyboard")
        }
        
        Button(action: actions.openBackgroundRefreshSettings) {
            Label("Arka Plan Yenileme", systemImage: "arrow.clockwise")
        }
        
        Divider()
        
        Button(action: {
            state.showAboutSheet = true
        }) {
            Label("Hakkında", systemImage: "info.circle")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}