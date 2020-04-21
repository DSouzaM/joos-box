interface Bar {
    abstract void bar();
}

public class Foo implements Bar {
  private static int a = 32768; // integer constants which fit into shorts are inlined
  protected static long b = (42L << 32) | 42;
  public static float c = 3.14159f;
  static double d = 3.14159d;

  public Foo() {}

  public int getA() {
    return a;
  }

  public void bar() {
      return;
  }
}
