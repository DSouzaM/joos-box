interface Bar {}

public class Foo implements Bar {
  private int a;
  public boolean b;

  public Foo() {
    a = 42;
    b = true;
  }

  public int getA() {
    return a;
  }
}
