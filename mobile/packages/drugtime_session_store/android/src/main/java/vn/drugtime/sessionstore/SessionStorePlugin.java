package vn.drugtime.sessionstore;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import java.io.File;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import android.util.AtomicFile;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

public final class SessionStorePlugin implements FlutterPlugin {
    private static final String KEY = "vn.drugtime.session.aes.v1";
    private static final int IV_SIZE = 12;
    private static final Object LOCK = new Object();
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        AtomicFile file = new AtomicFile(new File(context.getNoBackupFilesDir(), "auth_session.v1"));
        channel = new MethodChannel(binding.getBinaryMessenger(), "vn.drugtime/session_store",
                io.flutter.plugin.common.StandardMethodCodec.INSTANCE,
                binding.getBinaryMessenger().makeBackgroundTaskQueue());
        channel.setMethodCallHandler((call, result) -> {
            try {
                synchronized (LOCK) {
                    switch (call.method) {
                        case "read": result.success(read(file)); break;
                        case "write": write(file, (String) call.arguments); result.success(null); break;
                        case "clear": file.delete(); result.success(null); break;
                        default: result.notImplemented();
                    }
                }
            } catch (Exception exception) {
                result.error("session_storage", exception.getClass().getSimpleName(), null);
            }
        });
    }

    private static SecretKey key(boolean create) throws Exception {
        KeyStore store = KeyStore.getInstance("AndroidKeyStore");
        store.load(null);
        SecretKey key = (SecretKey) store.getKey(KEY, null);
        if (key != null || !create) return key;
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(KEY,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build());
        return generator.generateKey();
    }

    private static String read(AtomicFile file) throws Exception {
        byte[] stored;
        try {
            stored = file.readFully();
        } catch (java.io.FileNotFoundException e) {
            if (!file.getBaseFile().exists()) return null;
            throw e;
        }
        SecretKey key = key(false);
        if (key == null || stored.length < IV_SIZE + 16) {
            throw new IllegalStateException("Invalid encrypted session");
        }
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, stored, 0, IV_SIZE));
        return new String(cipher.doFinal(stored, IV_SIZE, stored.length - IV_SIZE), StandardCharsets.UTF_8);
    }

    private static void write(AtomicFile file, String session) throws Exception {
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key(true));
        byte[] iv = cipher.getIV();
        if (iv.length != IV_SIZE) throw new IllegalStateException("Unexpected IV size");
        byte[] encrypted = cipher.doFinal(session.getBytes(StandardCharsets.UTF_8));
        java.io.FileOutputStream output = file.startWrite();
        try {
            output.write(iv);
            output.write(encrypted);
            file.finishWrite(output);
        } catch (Exception exception) {
            file.failWrite(output);
            throw exception;
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }
}
