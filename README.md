```
Qleon/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/pakelcomedy/qleon/
│   │   │   │   ├── ui/
│   │   │   │   │   ├── SplashFragment.kt        # Splash Screen
│   │   │   │   │   ├── LoginFragment.kt         # Halaman login
│   │   │   │   │   ├── HomeFragment.kt          # Halaman utama (daftar chat)
│   │   │   │   │   ├── NewChatFragment.kt       # Halaman untuk memulai chat baru
│   │   │   │   │   └── ChatFragment.kt          # Halaman chat
│   │   │   │   ├── adapter/
│   │   │   │   │   └── ChatAdapter.kt           # Adapter untuk daftar chat atau pesan
│   │   │   │   ├── model/
│   │   │   │   │   ├── Chat.kt                  # Model untuk chat
│   │   │   │   │   ├── Message.kt               # Model untuk pesan
│   │   │   │   │   └── User.kt                  # Model untuk pengguna
│   │   │   │   ├── repository/
│   │   │   │   │   └── FirebaseRepository.kt    # Repository untuk Firebase
│   │   │   │   ├── viewmodel/
│   │   │   │   │   ├── LoginViewModel.kt        # ViewModel untuk Login
│   │   │   │   │   ├── HomeViewModel.kt         # ViewModel untuk Home
│   │   │   │   │   ├── NewChatViewModel.kt      # ViewModel untuk New Chat
│   │   │   │   │   └── ChatViewModel.kt         # ViewModel untuk Chat
│   │   │   │   ├── MainActivity.kt              # Host Activity untuk Fragment
│   │   │   │   ├── QleonApplication.kt          # Class Application (opsional)
│   │   │   └── res/
│   │   │       ├── layout/
│   │   │       │   ├── fragment_splash.xml      # Layout SplashFragment
│   │   │       │   ├── fragment_login.xml       # Layout LoginFragment
│   │   │       │   ├── fragment_home.xml        # Layout HomeFragment
│   │   │       │   ├── fragment_new_chat.xml    # Layout NewChatFragment
│   │   │       │   └── fragment_chat.xml        # Layout ChatFragment
│   │   │       ├── drawable/                    # Gambar atau ikon aplikasi
│   │   │       ├── values/
│   │   │       │   ├── colors.xml               # Warna aplikasi
│   │   │       │   ├── strings.xml              # String aplikasi
│   │   │       │   └── themes.xml               # Tema aplikasi
│   │   │       ├── navigation/
│   │   │       │   └── nav_graph.xml            # Navigasi antar fragment
│   │   │       ├── menu/                        # Menu opsional (jika digunakan)
│   │   │       └── mipmap/                      # Ikon aplikasi
│   ├── build.gradle                             # Gradle untuk modul app
├── build.gradle                                 # Gradle untuk project
└── google-services.json                         # File konfigurasi Firebase
```
