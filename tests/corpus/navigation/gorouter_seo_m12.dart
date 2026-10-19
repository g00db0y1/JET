
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RouterTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => HomePageWidget(),
        ),
        GoRoute(
          path: '/settings',
          title: 'Custom Settings',
          builder: (context, state) => SettingsDashboard(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => UserProfileScreen(),
        ),
      ],
    );
  }
}
