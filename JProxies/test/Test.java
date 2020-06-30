import java.io.UnsupportedEncodingException;
import java.util.ArrayList;

public class Test {

  public boolean booleanField = true;
  public int integerField = 100;
  public String stringField = "A STRING";
  public Object objectField = null;

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

  public static double testDoubleArray(double[] array) {
      //Inspired from jsum of #122
      double sum = 0;
      for (double value : array) {
          sum += value;
      }
      return sum;
  }

  public static java.util.HashMap testNull() {
    return null;
  }

  public static Object testArrayAsObject() throws UnsupportedEncodingException {
    byte[][] res = new byte[2][];
    res[0] = "Hello".getBytes("UTF8");
    res[1] = "World".getBytes("UTF8");
    return res;
  }

  public static double[] testDoubleArray() throws UnsupportedEncodingException {
    double[] res = {0.1, 0.2, 0.3};    
    return res;
  }
    
  public static double[][] testDoubleArray2D() throws UnsupportedEncodingException {
    double[][] res = {{0.1, 0.2, 0.3}, {0.4, 0.5, 0.6}};
    return res;
  }

  public static String[][] testStringArray2D() throws UnsupportedEncodingException {
    String[][] res = {{"Hello", "World"}, {"Goodbye", "World"}};
    return res;
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

  public int getInt() {
    return integerField;
  }

  public void setInt(int v) {
    integerField = v;
  }

  public String getString() {
    return stringField;
  }

  public void setString(String s) {
    stringField = s;
  }

  public Object getObject() {
    return objectField;
  }

  public void setObject(Object val) {
    objectField = val;
  }

  public String toString() {
      return "Test(" + integerField + ", " + stringField + ")";
  }

  public String testArrayArgs(int i) {
    return "int";
  }

  public String testArrayArgs(int[] i) {
    return "int[]";
  }

  public String testArrayArgs(int[][] i) {
    return "int[][]";
  }

  public String testArrayArgs(Object[] i) {
    return "java.lang.Object[]";
  }
}
