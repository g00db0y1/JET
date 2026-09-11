import 'package:test/test.dart';

import 'package:jet_builder/src/emitter/tailwind_mapper.dart';

void main() {
  group('TailwindMapper', () {
    group('edgeInsetsAllToPadding', () {
      test('maps 4px → p-1', () {
        expect(TailwindMapper.edgeInsetsAllToPadding(4), equals('p-1'));
      });
      test('maps 8px → p-2', () {
        expect(TailwindMapper.edgeInsetsAllToPadding(8), equals('p-2'));
      });
      test('maps 16px → p-4', () {
        expect(TailwindMapper.edgeInsetsAllToPadding(16), equals('p-4'));
      });
      test('maps 24px → p-6', () {
        expect(TailwindMapper.edgeInsetsAllToPadding(24), equals('p-6'));
      });
      test('maps 32px → p-8', () {
        expect(TailwindMapper.edgeInsetsAllToPadding(32), equals('p-8'));
      });
    });

    group('edgeInsetsSymmetricToPadding', () {
      test('maps horizontal:16, vertical:8 → px-4 py-2', () {
        expect(
          TailwindMapper.edgeInsetsSymmetricToPadding(horizontal: 16, vertical: 8),
          equals('px-4 py-2'),
        );
      });
      test('maps horizontal:32, vertical:16 → px-8 py-4', () {
        expect(
          TailwindMapper.edgeInsetsSymmetricToPadding(horizontal: 32, vertical: 16),
          equals('px-8 py-4'),
        );
      });
    });

    group('mainAxisAlignmentToJustify', () {
      test('center → justify-center', () {
        expect(
          TailwindMapper.mainAxisAlignmentToJustify('MainAxisAlignment.center'),
          equals('justify-center'),
        );
      });
      test('spaceBetween → justify-between', () {
        expect(
          TailwindMapper.mainAxisAlignmentToJustify('MainAxisAlignment.spaceBetween'),
          equals('justify-between'),
        );
      });
      test('start → justify-start', () {
        expect(
          TailwindMapper.mainAxisAlignmentToJustify('MainAxisAlignment.start'),
          equals('justify-start'),
        );
      });
    });

    group('crossAxisAlignmentToItems', () {
      test('center → items-center', () {
        expect(
          TailwindMapper.crossAxisAlignmentToItems('CrossAxisAlignment.center'),
          equals('items-center'),
        );
      });
      test('stretch → items-stretch', () {
        expect(
          TailwindMapper.crossAxisAlignmentToItems('CrossAxisAlignment.stretch'),
          equals('items-stretch'),
        );
      });
    });

    group('fontSizeToHeadingTag', () {
      test('30 → h1', () {
        expect(TailwindMapper.fontSizeToHeadingTag(30), equals('h1'));
      });
      test('24 → h2', () {
        expect(TailwindMapper.fontSizeToHeadingTag(24), equals('h2'));
      });
      test('18 → h3', () {
        expect(TailwindMapper.fontSizeToHeadingTag(18), equals('h3'));
      });
      test('14 → null (body text)', () {
        expect(TailwindMapper.fontSizeToHeadingTag(14), isNull);
      });
    });

    group('sizedBoxWidthToClass', () {
      test('16px → w-4', () {
        expect(TailwindMapper.sizedBoxWidthToClass(16), equals('w-4'));
      });
      test('8px → w-2', () {
        expect(TailwindMapper.sizedBoxWidthToClass(8), equals('w-2'));
      });
    });
  });
}
