import 'dart:math';

/// Computes stuff relating to off-course distance
///

/// frequency is a method that, given a sensitivity in the range 0<s<=1
/// and x in the range 0<x<1
/// returns a number that indicates the 'urgency' of x
///
/// To explain: if x is close to 0, that's not urgent - will return 0
/// At mid (s=0.5) sensitivity, urgency is linear with x
/// At high sensitivity, urgency increases faster than x
/// At lower sensitivity, urgency increases slower than x
/// But always u=1 when x=1.
/// m is the degree of acuteness, 5 is about right for what I want,
/// bigger numbers make the function more 'blunt', smaller num
/// // deprecated in favour of 'interval' method below:
// double urgency(double x, double s, [ int m = 5]) {
//   return (pow(x,m)*(1-s) + pow(x,(1.0/m))*s);
// }
//
// double offcourse(double error, double minError, double maxError, double minFreq, double maxFreq, int sensitivity) {
//   // print("Error $error");
//   if (error < minError) return 0;
//   if (error > maxError) return maxFreq.toDouble();
//   double e = (error-minError)/(maxError-minError); // scale to 0..1
//
//   // scale to minFreq .. maxFreq
//   double freq = urgency(e, sensitivity/9.0)*(maxFreq-minFreq)+minFreq;
//   // print("Err $error, freq $freq");
//   return freq;
// }

// ken suggests:
double interval(int sensitivity, int error) {
  error = error.abs();
  return min(5, ((12.0-sensitivity)/2) * (1.0-(error-1.0)/(error+1.0))); // was 19, not 12
}
main() {
  // test
  for (int i=0;i<40; i++) {
    print("$i "
        +"  "+interval(1, i).toStringAsFixed(2)
        +"  "+interval(5, i).toStringAsFixed(2)
        +"  "+interval(10, i).toStringAsFixed(2)
    );
  }
  // for (double i=0;i<40; i++) {
  //   print("$i "+"  "+offcourse(i, 10, 30, 2, 8, 1).toStringAsFixed(2)+" "+offcourse(i, 10, 30, 2, 8, 5).toStringAsFixed(2)+"  "+offcourse(i, 10, 30, 2, 8, 9).toStringAsFixed(2));
  // }
}
