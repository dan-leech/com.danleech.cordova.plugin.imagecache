package com.danleech.cordova.plugin.imagecache;

import android.util.Log;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.EOFException;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.math.BigInteger;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Iterator;

public class ImageCachePlugin extends CordovaPlugin {
    private static final String ACTION_STORE = "storeKey";
    private static final String ACTION_APPEND = "appendKey";
    private static final String ACTION_GET = "getKey";
    private static final String TAG = "ImageCachePlugin";
    private CallbackResponse callbackResponse;

    private static String sha1Hash(String input) {
        try {
            // getInstance() method is called with algorithm SHA-1
            MessageDigest md = MessageDigest.getInstance("SHA-1");

            // digest() method is called
            // to calculate message digest of the input string
            // returned as array of byte
            byte[] messageDigest = md.digest(input.getBytes());

            // Convert byte array into signum representation
            BigInteger no = new BigInteger(1, messageDigest);

            // Convert message digest into hex value
            StringBuilder hashtext = new StringBuilder(no.toString(16));

            // Add preceding 0s to make it 32 bit
            while (hashtext.length() < 32) {
                hashtext.insert(0, "0");
            }

            // return the HashText
            return hashtext.toString();
        }

        // For specifying wrong message digest algorithms
        catch (NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        callbackResponse = new CallbackResponse(callbackContext);

        try {
            final ImageCachePlugin self = this;
            if (ACTION_STORE.equals(action)) {
                String key = sha1Hash(args.getString(0));
                Long timestamp = args.getLong(1);
                JSONObject data = args.getJSONObject(2);
                String mime = args.getString(3);
                int dataSize = args.getInt(4);

                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        int offset = 0;

                        try {
                            File tempDir = cordova.getContext().getCacheDir(); // context being the Activity pointer
                            File outputFile = new File(tempDir + "/" + key + ".tmp"); // File.createTempFile(key, "tmp", outputDir);
                            if (outputFile.exists()) {
                                boolean deleted = outputFile.delete();
                            }

                            try (DataOutputStream out = new DataOutputStream(new FileOutputStream(outputFile))) {
                                // write timestamp
                                out.writeLong(timestamp);

                                // write mime/type
                                out.writeInt(mime.length());
                                out.writeBytes(mime);

                                // write data
                                out.writeInt(dataSize);
                                offset = out.size();

                                Log.d(TAG, "data size:" + dataSize);
                                Log.d(TAG, "data length:" + data.length());
                                byte[] bytes = new byte[data.length()];

                                Iterator<String> iter = data.keys();
                                while (iter.hasNext()) {
                                    String key = iter.next();
                                    try {
                                        Object value = data.get(key);
                                        byte b = (byte)(((int)value) & 0xFF);
                                        bytes[Integer.parseInt(key)] = b;
                                    } catch (JSONException e) {
                                        callbackResponse.send(PluginResult.Status.ERROR, "parse data json error", false);
                                        return;
                                    }
                                }

                                out.write(bytes, 0, bytes.length);
                            }
                        } catch (NullPointerException e) {
//				// This is a bug in the Android implementation of the Java Stack
//				NoModificationAllowedException realException = new NoModificationAllowedException(inputURL.toString());
//				realException.initCause(e);
//				throw realException;
                            e.printStackTrace();
                            throw e;
                        } catch (Exception e) {
                            e.printStackTrace();
                        }

                        callbackResponse.send(PluginResult.Status.OK, Integer.toString(offset), false);
                    }
                });
                return true;
            } else if (ACTION_APPEND.equals(action)) {
                String key = sha1Hash(args.getString(0));
                JSONObject data = args.getJSONObject(1);
                int dataOffset = args.getInt(2);

                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        try {
                            File tempDir = cordova.getContext().getCacheDir(); // context being the Activity pointer
                            File outputFile = new File(tempDir + "/" + key + ".tmp"); // File.createTempFile(key, "tmp", outputDir);

                            if (outputFile.exists()) {
                                try (DataOutputStream out = new DataOutputStream(new FileOutputStream(outputFile, true))) {
                                    Log.d(TAG, "data length:" + data.length());
                                    byte[] bytes = new byte[data.length()];

                                    Iterator<String> iter = data.keys();
                                    while (iter.hasNext()) {
                                        String key = iter.next();
                                        try {
                                            Object value = data.get(key);
                                            byte b = (byte)(((int)value) & 0xFF);
                                            bytes[Integer.parseInt(key)] = b;
                                        } catch (JSONException e) {
                                            callbackResponse.send(PluginResult.Status.ERROR, "parse data json error", false);
                                            return;
                                        }
                                    }

                                    out.write(bytes, 0, bytes.length);

                                    callbackResponse.send(PluginResult.Status.OK, false);
                                } catch (NullPointerException e) {
//				// This is a bug in the Android implementation of the Java Stack
//				NoModificationAllowedException realException = new NoModificationAllowedException(inputURL.toString());
//				realException.initCause(e);
//				throw realException;
                                    e.printStackTrace();
                                    throw e;
                                } catch (Exception e) {
                                    e.printStackTrace();
                                }
                            } else {
                                callbackResponse.send(PluginResult.Status.ERROR, false);
                                return;
                            }
                        } catch (Exception e) {
                            callbackResponse.send(PluginResult.Status.ERROR, false);
                        }
                    }
                });
                return true;
            } else if (ACTION_GET.equals(action)) {
                Log.d(TAG, "getKey key:" + args.getString(0));
                String key = sha1Hash(args.getString(0));
                Long timestamp = args.getLong(1);

                cordova.getThreadPool().execute(new Runnable() {
                    public void run() {
                        File tempDir = cordova.getContext().getCacheDir(); // context being the Activity pointer
                        File inputFile = new File(tempDir + "/" + key + ".tmp");

                        if (inputFile.exists()) {
                            JSONObject message = new JSONObject();

                            try {
                                try (DataInputStream in = new DataInputStream(new FileInputStream(inputFile))) {
                                    long inTimestamp = in.readLong();

                                    if (inTimestamp < timestamp) {
                                        boolean deleted = inputFile.delete();
                                        callbackResponse.send(PluginResult.Status.ERROR, false);
                                        return;
                                    }

                                    int len = in.readInt();
                                    StringBuilder inMime = new StringBuilder();
                                    for (int i = 0; i < len; i++) {
                                        inMime.append((char) in.readByte());
                                    }

                                    // read image data
                                    len = in.readInt();

                                    byte[] rawData = new byte[len];
                                    in.readFully(rawData); // prevent EOF

                                    JSONArray byteArray =  new JSONArray();
                                    for (byte aRawData : rawData) {
                                        byteArray.put(aRawData & 0xFF);
                                    }

                                    message.put("timestamp", inTimestamp);
                                    message.put("mimeType", inMime.toString());
                                    message.put("imageData", byteArray);
                                } catch (EOFException e) {
                                    callbackResponse.send(PluginResult.Status.ERROR, "eof", false);
                                    return;
                                }
                            } catch (Exception e) {
                                e.printStackTrace();
                            }

                            callbackResponse.send(PluginResult.Status.OK, message, false);
                            return;
                        }

                        callbackResponse.send(PluginResult.Status.ERROR,false);
                    }
                });
                return true;
            } else {
                callbackResponse.send(PluginResult.Status.INVALID_ACTION, false);
                return false;
            }
        } catch (Exception e) {
            Log.d(TAG, "execute main exception");
            e.printStackTrace();

            callbackResponse.send(PluginResult.Status.JSON_EXCEPTION, false);
            return false;
        }
    }
}
