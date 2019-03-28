// Sensibilidad del sensor en V/A
float SENSIBILITY = 0.185;   // Modelo 5A
//float SENSIBILITY = 0.100; // Modelo 20A
//float SENSIBILITY = 0.066; // Modelo 30A
 
int SAMPLESNUMBER = 100;
 
void setup() 
{
   Serial.begin(9600);
}
 
void printMeasure(int prefix,String dots, float value, String postfix)
{
   Serial.print(prefix);
   Serial.print(dots);
   Serial.print(value, 3);
   Serial.println(postfix);
}
int i = 0;
void loop()
{
   float current = getCorriente(SAMPLESNUMBER);
   float currentRMS = 0.707 * current;
   float power = 5 * currentRMS;
 
   //printMeasure("Intensidad: ", current, "A ,");
   //printMeasure("Irms: ", currentRMS, "A ,");
   printMeasure(i,", ", power, "");
   i++;
   delay(500);
}
 
float getCorriente(int samplesNumber)
{
   float voltage;
   float corrienteSum = 0;
   for (int i = 0; i < samplesNumber; i++)
   {
      voltage = analogRead(A0) * 5.0 / 1023.0;
      corrienteSum += (voltage - 2.5) / SENSIBILITY;
   }
   return(corrienteSum / samplesNumber);
}
