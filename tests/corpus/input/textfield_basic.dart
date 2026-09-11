// corpus: textfield_basic
// Tests: TextField → <input type="text"> with @client, Form wrapper
// Source: https://docs.flutter.dev/ui/widgets/input
import 'package:flutter/material.dart';

class TextFieldDemo extends StatelessWidget {
  const TextFieldDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Username',
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
