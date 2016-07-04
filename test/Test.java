import java.util.ArrayList;

public class Test {

  public int integerField = 100;
  public String stringField = "A STRING";

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
