const int readMask = 1 << 13;
const int likeMask = 1 << 14;
const int lateRead = 1 << 15;
const int collection = 1 << 16;

extension FlagHelper on int {
  bool isFlagSet(int flag) {
    return this & flag == flag;
  }

  int setMask(int flag) {
    return this | flag;
  }

  int unSetMask(int flag) {
    return this ^ flag;
  }
}
