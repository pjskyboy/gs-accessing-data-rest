package crypto;

import javax.crypto.*;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;

public class SimpleCrypto
{
    public static void main(String[] argv) {

        try{

            KeyGenerator keygenerator = KeyGenerator.getInstance("DES");
            SecretKey myDesKey = keygenerator.generateKey();

            Cipher desCipher;

            // Create the cipher
            desCipher = Cipher.getInstance("DES/ECB/PKCS5Padding");

            //sensitive information
            byte[] text = "No body can see me".getBytes();

            for (int i=0; i<10; i++) {

                System.out.println("Text [Byte Format] : " + text);
                System.out.println("Text : " + new String(text));

                // Initialize the cipher for encryption
                desCipher.init(Cipher.ENCRYPT_MODE, myDesKey);
                // Encrypt the text
                byte[] textEncrypted = desCipher.doFinal(text);

                System.out.println("Text Encrypted : " + textEncrypted);

                // Initialize the same cipher for decryption
                desCipher.init(Cipher.DECRYPT_MODE, myDesKey);

                // Decrypt the text
                byte[] textDecrypted = desCipher.doFinal(textEncrypted);

                System.out.println("Text Decrypted : " + new String(textDecrypted));
            }
        }catch(NoSuchAlgorithmException | NoSuchPaddingException | InvalidKeyException | IllegalBlockSizeException | BadPaddingException e) {
            e.printStackTrace();
        }
    }
}
