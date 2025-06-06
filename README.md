```
Qleon/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/pakelcomedy/qleon/
│   │   │   │   ├── ui/
│   │   │   │   │   ├── splash/
│   │   │   │   │   │   └── SplashFragment.kt               # Splash Screen
│   │   │   │   │   ├── auth/
│   │   │   │   │   │   ├── LoginFragment.kt                # Halaman login
│   │   │   │   │   │   └── LoginViewModel.kt                # Halaman login
│   │   │   │   │   ├── home/
│   │   │   │   │   │   ├── HomeFragment.kt                 # Halaman utama (daftar chat)
│   │   │   │   │   │   ├── HomeViewPagerAdapter.kt                 # Halaman utama (daftar chat)
│   │   │   │   │   ├── chat/
│   │   │   │   │   │   ├── ChatFragment.kt                 # Halaman chat
│   │   │   │   │   │   ├── ChatViewModel.kt                # ViewModel untuk Chat
│   │   │   │   │   ├── newchat/
│   │   │   │   │   │   ├── NewChatFragment.kt              # Halaman untuk memulai chat baru
│   │   │   │   │   │   └── NewChatViewModel.kt             # ViewModel untuk New Chat
│   │   │   │   │   ├── homechat/
│   │   │   │   │   │   ├── HomeChatFragment.kt             # Fragment untuk chat dari Home
│   │   │   │   │   │   ├── HomeChatViewModel.kt            # ViewModel untuk HomeChat
│   │   │   │   ├── adapter/
│   │   │   │   │   ├── ChatAdapter.kt                      # Adapter untuk daftar chat atau pesan
│   │   │   │   │   ├── ContactAdapter.kt                      # Adapter untuk daftar Home atau pesan
│   │   │   │   ├── model/
│   │   │   │   │   ├── Chat.kt                             # Model untuk chat
│   │   │   │   │   ├── Message.kt                          # Model untuk pesan
│   │   │   │   │   └── User.kt                             # Model untuk pengguna
│   │   │   │   ├── repository/
│   │   │   │   │   └── FirebaseRepository.kt               # Repository untuk Firebase
│   │   │   │   ├── viewmodel/
│   │   │   │   │   ├── LoginViewModel.kt                   # ViewModel untuk Login
│   │   │   │   ├── MainActivity.kt                         # Host Activity untuk Fragment
│   │   │   └── res/
│   │   │       ├── layout/
│   │   │       │   ├── fragment_splash.xml                 # Layout SplashFragment
│   │   │       │   ├── fragment_login.xml                  # Layout LoginFragment
│   │   │       │   ├── fragment_home.xml                   # Layout HomeFragment
│   │   │       │   ├── fragment_home_chat.xml              # Layout HomeChatFragment
│   │   │       │   ├── item_home_chat.xml                  # Layout ItemHomeChat (for RecyclerView items)
│   │   │       │   ├── fragment_new_chat.xml               # Layout NewChatFragment
│   │   │       │   └── fragment_chat.xml                   # Layout ChatFragment
│   │   │       ├── drawable/                               # Gambar atau ikon aplikasi
│   │   │       ├── values/
│   │   │       │   ├── colors.xml                          # Warna aplikasi
│   │   │       │   ├── strings.xml                         # String aplikasi
│   │   │       │   └── themes.xml                          # Tema aplikasi
│   │   │       ├── navigation/
│   │   │       │   └── nav_graph.xml                       # Navigasi antar fragment
│   │   │       ├── menu/                                   # Menu opsional (jika digunakan)
│   │   │       └── mipmap/                                 # Ikon aplikasi
│   ├── build.gradle                                        # Gradle untuk modul app
├── build.gradle                                            # Gradle untuk project
└── google-services.json                                    # File konfigurasi Firebase
```
