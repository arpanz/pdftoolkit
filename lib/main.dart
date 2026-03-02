// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.

// // The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.
//
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:provider/provider.dart';
// // import 'core/theme/app_theme.dart';
// // import 'core/providers/app_provider.dart';
// // import 'features/workspace/workspace_screen.dart';
// // import 'features/files/files_screen.dart';
// // import 'features/settings/settings_screen.dart';
// // import 'rust/frb_generated.dart';
// //
// // void main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //
// //   // Initialize Rust bridge
// //   await RustLib.init();
// //
// //   // Set system UI overlay style
// //   SystemChrome.setSystemUIOverlayStyle(
// //     const SystemUiOverlayStyle(
// //       statusBarColor: Colors.transparent,
// //       statusBarIconBrightness: Brightness.light,
// //       systemNavigationBarColor: AppColors.bgCard,
// //       systemNavigationBarIconBrightness: Brightness.light,
// //     ),
// //   );
// //
// //   runApp(
// //     ChangeNotifierProvider(
// //       create: (_) => AppProvider()..init(),
// //       child: const BatchPdfApp(),
// //     ),
// //   );
// // }
// //
// // class BatchPdfApp extends StatelessWidget {
// //   const BatchPdfApp({super.key});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final isDark = context.watch<AppProvider>().isDarkMode;
// //
// //     return MaterialApp(
// //       title: 'BatchPDF Pro',
// //       debugShowCheckedModeBanner: false,
// //       theme: AppTheme.lightTheme,
// //       darkTheme: AppTheme.darkTheme,
// //       themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
// //       home: const AppShell(),
// //     );
// //   }
// // }
// //
// // class AppShell extends StatefulWidget {
// //   const AppShell({super.key});
// //
// //   @override
// //   State<AppShell> createState() => _AppShellState();
// // }
// //
// // class _AppShellState extends State<AppShell> {
// //   int _currentIndex = 0;
// //
// //   final List<Widget> _screens = const [
// //     WorkspaceScreen(),
// //     FilesScreen(),
// //     SettingsScreen(),
// //   ];
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: AppColors.bgDark,
// //       body: IndexedStack(
// //         index: _currentIndex,
// //         children: _screens,
// //       ),
// //       bottomNavigationBar: _BottomNav(
// //         currentIndex: _currentIndex,
// //         onTap: (index) => setState(() => _currentIndex = index),
// //       ),
// //     );
// //   }
// // }
// //
// // class _BottomNav extends StatelessWidget {
// //   final int currentIndex;
// //   final ValueChanged<int> onTap;
// //
// //   const _BottomNav({required this.currentIndex, required this.onTap});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       decoration: const BoxDecoration(
// //         color: AppColors.bgCard,
// //         border: Border(top: BorderSide(color: AppColors.border, width: 1)),
// //       ),
// //       child: SafeArea(
// //         child: Padding(
// //           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
// //           child: Row(
// //             mainAxisAlignment: MainAxisAlignment.spaceAround,
// //             children: [
// //               _NavItem(
// //                 icon: Icons.grid_view_rounded,
// //                 activeIcon: Icons.grid_view_rounded,
// //                 label: 'Workspace',
// //                 isActive: currentIndex == 0,
// //                 onTap: () => onTap(0),
// //               ),
// //               _NavItem(
// //                 icon: Icons.folder_outlined,
// //                 activeIcon: Icons.folder_rounded,
// //                 label: 'Files',
// //                 isActive: currentIndex == 1,
// //                 onTap: () => onTap(1),
// //               ),
// //               _NavItem(
// //                 icon: Icons.settings_outlined,
// //                 activeIcon: Icons.settings_rounded,
// //                 label: 'Settings',
// //                 isActive: currentIndex == 2,
// //                 onTap: () => onTap(2),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // class _NavItem extends StatelessWidget {
// //   final IconData icon;
// //   final IconData activeIcon;
// //   final String label;
// //   final bool isActive;
// //   final VoidCallback onTap;
// //
// //   const _NavItem({
// //     required this.icon,
// //     required this.activeIcon,
// //     required this.label,
// //     required this.isActive,
// //     required this.onTap,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return GestureDetector(
// //       onTap: onTap,
// //       behavior: HitTestBehavior.opaque,
// //       child: AnimatedContainer(
// //         duration: const Duration(milliseconds: 200),
// //         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
// //         decoration: BoxDecoration(
// //           color: isActive ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
// //           borderRadius: BorderRadius.circular(12),
// //         ),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Icon(
// //               isActive ? activeIcon : icon,
// //               color: isActive ? AppColors.primary : AppColors.textMuted,
// //               size: 22,
// //             ),
// //             const SizedBox(height: 3),
// //             Text(
// //               label,
// //               style: TextStyle(
// //                 color: isActive ? AppColors.primary : AppColors.textMuted,
// //                 fontSize: 10,
// //                 fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
//
// import 'package:flutter/material.dart';
// import 'package:pdftoolkit/src/rust/api/simple.dart';
// import 'package:pdftoolkit/src/rust/frb_generated.dart';
//
// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//         body: Center(
//           child: Text(
//             'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
//           ),
//         ),
//       ),
//     );
//   }
// }
//

import 'package:flutter/material.dart';
import 'package:pdftoolkit/src/rust/api/simple.dart';
import 'package:pdftoolkit/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
        body: Center(
          child: Text(
            'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
          ),
        ),
      ),
    );
  }
}
