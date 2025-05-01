import tensorflow as tf

# 1) Load the Keras model
model = tf.keras.models.load_model('model-tiny.h5')

# 2) Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()  # uses defaults; see docs for quantization, etc. :contentReference[oaicite:1]{index=1}

# 3) Write out the .tflite file
with open('pitch_crepe_micro.tflite', 'wb') as f:
    f.write(tflite_model)
