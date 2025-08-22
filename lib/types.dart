import 'package:collection/collection.dart';

/// Represents a rime in the Chinese language.
///
/// Note that the `in_` rime is represented with an underscore
/// to avoid conflicts with Dart's reserved keywords.
///
/// Also note that the `v` and `ve` represent the 'ü'
/// and 'üe' rime, respectively.
/// |    | C0 | C1 | C2 | C3 |
/// |----|----|----|----|----|
/// | R0 | a  | ia | ua |    |
/// | R1 | e  | ie | uo | üe |
/// | R2 |    | i  | u  | ü  |
/// | R3 | ai |    | uai|    |
/// | R4 | ei |    | ui |    |
/// | R5 | ao | iao|    |    |
/// | R6 | ou | iu |    |    |
/// | R7 | er |    |    |    |
/// | R8 | an | ian| uan| üan|
/// | R9 | en | in | un | ün |
/// | R10| ang|iang|uang|    |
/// | R11| eng| ing|ueng|    |
/// | R12| ong|iong|    |    |
///
enum HanziRime {
  a(0, 0),
  ia(0, 1),
  ua(0, 2),
  e(1, 0),
  ie(1, 1),
  uo(1, 2), // Notate "o" after b,p,m,f.
  ve(1, 3), // 'üe' rime : Notate 'ue' after j,q,x.
  i(2, 1),
  u(2, 2),
  v(2, 3), // 'ü' rime :  Notate 'u' after j,q,x.
  ai(3, 0),
  uai(3, 2),
  ei(4, 0),
  ui(4, 2), // With onset, Notate 'ui'.
  ao(5, 0),
  iao(5, 1),
  ou(6, 0),
  iu(6, 1), // Without onset, Notate 'you'.
  er(7, 0),
  an(8, 0),
  ian(8, 1),
  uan(8, 2),
  van(8, 3), // 'üan' rime : Notate 'uan' after j,q,x.
  en(9, 0),
  in_(9, 1),
  un(9, 2), // With onset, Notate 'un'.
  vn(9, 3), // 'ün' rime : Notate 'un' after j,q,x.
  ang(10, 0),
  iang(10, 1),
  uang(10, 2),
  eng(11, 0),
  ing(11, 1),
  ueng(11, 2),
  ong(12, 0),
  iong(12, 1),
  other(12, 3); // Other rime, not in the table.

  final int row, col;
  const HanziRime(this.row, this.col);

  /// Returns the string representation of the rime.
  ///
  /// The format is different from the standard `toString()`.
  /// For example, HanziRime.zh is represented as 'zh',
  /// the standard `toString()` would return 'HanziRime.zh'.
  ///
  /// There are some special cases:
  /// - `in_` is represented as 'in' (without underscore).
  /// - `v` is represented as 'ü'.
  /// - `ve` is represented as 'üe'.
  @override
  String toString() {
    switch (this) {
      case in_:
        return name.replaceFirst('_', '');
      case v:
        return 'ü';
      case ve:
        return 'üe';
      case vn:
        return 'ün';
      case van:
        return 'üan';
      default:
        return name;
    }
  }

  /// Test whether the given [rime] matches with`this` rime, accompanied by the [onset].
  ///
  /// Pinyin changes depending on the onset.
  /// In the other words, other words, it is context-sensitive.
  ///
  /// To follow this behavior, the `matches` method needs to be
  /// with the [onset] parameter.
  ///
  /// Followings are the rules:
  /// - When HanziOnset is `b`, `p`, `m`, or `f`,
  ///   - uo matches with `o`.
  /// - When HanziOnset is `j`, `q`, or `x`,
  ///   - ve matches with `ue`.
  ///   - v matches with `u`.
  ///   - vn matches with `un`.
  ///   - van matches with `uan`.
  /// - When HanziOnset is `none`,
  ///   - i matches with `yi`.
  ///   - ie matches with `ye`.
  ///   - ia matches with `ya`.
  ///   - iu matches with `you`.
  ///   - iao matches with `yao`.
  ///   - in matches with `yin`.
  ///   - ian matches with `yan`.
  ///   - iong matches with `yong`.
  ///   - ing matches with `ying`.
  ///   - iang matches with `yang`.
  ///   - u matches with `wu`.
  ///   - uo matches with `wo`.
  ///   - ua matches with `wa`.
  ///   - ui matches with `wei`.
  ///   - uai matches with `wai`.
  ///   - un matches with `wen`.
  ///   - uang matches with `wang`.
  ///   - ueng matches with `weng`.
  ///   - v matches with `yu`.
  ///   - ve matches with `yue`.
  ///   - vn matches with `yun`.
  ///   - van matches with `yuan`.
  bool matches(String rime, HanziOnset onset) {
    if ({
      HanziOnset.b,
      HanziOnset.p,
      HanziOnset.m,
      HanziOnset.f,
    }.contains(onset)) {
      if (this == HanziRime.uo) {
        return rime == 'o';
      }
    } else if ({HanziOnset.j, HanziOnset.q, HanziOnset.x}.contains(onset)) {
      if (this == HanziRime.ve) {
        return rime == 'ue';
      } else if (this == HanziRime.v) {
        return rime == 'u';
      } else if (this == HanziRime.vn) {
        return rime == 'un';
      } else if (this == HanziRime.van) {
        return rime == 'uan';
      } else if (this == HanziRime.u) {
        // v=>u mapping is exclusive with u.
        return false;
      } else if (this == HanziRime.un) {
        // vn=>un mapping is exclusive with un.
        return false;
      } else if (this == HanziRime.uan) {
        // van=>uan mapping is exclusive with uan.
        return false;
      }
    } else if (onset == HanziOnset.none) {
      switch (this) {
        case HanziRime.i:
          return rime == 'yi';
        case HanziRime.ie:
          return rime == 'ye';
        case HanziRime.ia:
          return rime == 'ya';
        case HanziRime.iu:
          return rime == 'you';
        case HanziRime.iao:
          return rime == 'yao';
        case HanziRime.in_:
          return rime == 'yin';
        case HanziRime.ian:
          return rime == 'yan';
        case HanziRime.iong:
          return rime == 'yong';
        case HanziRime.ing:
          return rime == 'ying';
        case HanziRime.iang:
          return rime == 'yang';
        case HanziRime.u:
          return rime == 'wu';
        case HanziRime.uo:
          return rime == 'wo';
        case HanziRime.ua:
          return rime == 'wa';
        case HanziRime.ui:
          return rime == 'wei';
        case HanziRime.uai:
          return rime == 'wai';
        case HanziRime.un:
          return rime == 'wen';
        case HanziRime.uang:
          return rime == 'wang';
        case HanziRime.ueng:
          return rime == 'weng';
        case HanziRime.v:
          return rime == 'yu';
        case HanziRime.ve:
          return rime == 'yue';
        case HanziRime.vn:
          return rime == 'yun';
        case HanziRime.van:
          return rime == 'yuan';
        default: // Other cases.
          break;
      }
    }

    return rime == toString();
  }
}

extension HanziRimeOnString on String {
  /// Context free conversion from string to HanziRime.
  ///
  /// Do not use this method to check the `native` rime
  /// of Hanzi. This is for the UI programming usage.
  ///
  /// This conversion is the reverse of [HanziRime.toString].
  HanziRime toHanziRime() {
    final result = HanziRime.values.firstWhereOrNull(
      (r) => (r.toString() == this),
    );

    return result ?? HanziRime.other;
  }
}

/// Represents the onset of a Chinese character.
///
/// The enum values has corresponding position
/// (r,c) in pinyin table.
///
///
/// |    | c0 | c1 | c2 | c3 | c4 |
/// |----|----|----|----|----|----|
/// | r0 | b  | d  |    |    | g  |
/// | r1 | p  | t  |    |    | k  |
/// | r2 | m  | n  |    |    |    |
/// | r3 |    | z  | zh | j  |    |
/// | r4 |    | c  | ch | q  |    |
/// | r5 | f  | s  | sh | x  |  h |
/// | r6 |    | l  | r  |    |    |
///
/// Value `none` is an exceptional case.
/// It is used when there is no onset in the character.
/// To avoid the conflict with other onset value,
/// Its coordinate is set to (6,4) where no onset exists.
enum HanziOnset {
  b(0, 0),
  p(1, 0),
  m(2, 0),
  f(5, 0),
  d(0, 1),
  t(1, 1),
  n(2, 1),
  l(6, 1),
  g(0, 4),
  k(1, 4),
  h(5, 4),
  j(3, 3),
  q(4, 3),
  x(5, 3),
  zh(3, 2),
  ch(4, 2),
  sh(5, 2),
  r(6, 2),
  z(3, 1),
  c(4, 1),
  s(5, 1),
  none(6, 4); // This is exceptional case. no onset.

  /// The row and column in the pinyin table.
  final int row, col;

  const HanziOnset(this.row, this.col);
}

extension HanziOnsetOnString on String {
  HanziOnset toHanziOnset() {
    final result = HanziOnset.values.firstWhereOrNull((o) => o.name == this);

    return result ?? HanziOnset.none;
  }
}

enum HanziTone {
  first(1),
  second(2),
  third(3),
  fourth(4),
  light(5);

  /// The tone number.
  final int number;

  const HanziTone(this.number);

  @override
  String toString() {
    return number.toString();
  }
}
