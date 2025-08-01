import SwiftUI

struct AboutView: View {
    @Binding var showAboutSheet: Bool
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(20)
                            .shadow(color: .blue.opacity(0.2), radius: 10)
                        
                        Text("Pano Yöneticisi")
                            .font(.title2.bold())
                        
                        Text("Sürüm 1.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Geliştirici")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Ahmet")
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                    
                    Link(destination: URL(string: "https://github.com/AhmetShbz")!) {
                        LinkRowView(icon: "link", title: "GitHub")
                    }
                    
                    Link(destination: URL(string: "https://www.buymeacoffee.com/ahmetknkc")!) {
                        LinkRowView(icon: "cup.and.saucer", title: "Bana Kahve Ismarla")
                    }
                } header: {
                    Text("İletişim")
                }
                
                Section {
                    Text("Bu uygulama, kopyaladığınız metinleri güvenli bir şekilde saklar ve istediğiniz zaman erişmenizi sağlar. Tüm verileriniz yalnızca sizin cihazınızda tutulur ve üçüncü taraflarla paylaşılmaz.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Hakkında")
                }
            }
            .navigationTitle("Hakkında")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tamam") {
                        showAboutSheet = false
                    }
                }
            }
        }
    }
}

struct LinkRowView: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote)
        }
    }
}