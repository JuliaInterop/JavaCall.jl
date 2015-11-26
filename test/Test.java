import java.util.ArrayList;

public class Test {

  public static final boolean boolval = false;
  public static final char charval = 'a';
  public static final byte byteval = 105;
  public static final short shortval = 15000;
  public static final int intval = 30000;
  public static final long longval = 123123;
  public static final float floatval = 3.14f;
  public static final double doubleval = 1.404d;

  public static short testShort(short i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static int testInt(int i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static double testDouble(double i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static long testLong(long i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static float testFloat(float i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static String testString(String i) {
      System.out.print("In Java, recd: ");System.out.println(i);
      return i;
  }

  public static java.util.HashMap testNull() {
    return null;
  }

  public static ArrayList<String> testArrayList() {

      ArrayList<String> res=new ArrayList<String>();
      res.add("Hello");
      res.add("World");
      return res;
  }


  public static void main(String[] args) {
       testInt(1);
       testFloat(1.0f); 
       testDouble(1.0d);
       testString("Hello Java");
  }

  public class TestInner{
      public String innerString() {
        return "from inner";
      }
  }

}
