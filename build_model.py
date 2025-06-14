# File: 1_build_model.py

import sqlite3
import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.preprocessing import MinMaxScaler
import joblib
import json
import os

print(f"TensorFlow Version: {tf.__version__}")

# --- Langkah 1: Definisi Direktori ---
ASSETS_DIR = 'assets_for_flutter'
if not os.path.exists(ASSETS_DIR):
    os.makedirs(ASSETS_DIR)

# --- Langkah 2: Memuat Semua Data dari Tabel Bahaya ---
print("\nLangkah 2: Memuat data dari data.db...")
try:
    conn = sqlite3.connect('data.db')
    query = "SELECT lokasi_id, rendah, sedang, tinggi, total, kelas_bahaya, kelas_resiko FROM bahaya"
    df = pd.read_sql_query(query, conn)
    conn.close()
    print(f"Data berhasil dimuat. Jumlah baris: {len(df)}")
except Exception as e:
    print(f"Error: Gagal memuat data. Detail: {e}")
    exit()

# --- Langkah 3: Feature Engineering Komprehensif ---
print("\nLangkah 3: Feature Engineering untuk semua atribut...")
kolom_numerik = ['rendah', 'sedang', 'tinggi', 'total']
kolom_kategorikal = ['kelas_bahaya', 'kelas_resiko']

scaler = MinMaxScaler()
df_numerik_scaled = pd.DataFrame(scaler.fit_transform(df[kolom_numerik]), columns=kolom_numerik)
joblib.dump(scaler, os.path.join(ASSETS_DIR, 'scaler_bahaya.pkl'))
print("Fitur numerik dinormalisasi.")

df_kategorikal_encoded = pd.get_dummies(df[kolom_kategorikal], prefix=['bahaya', 'risiko'])
print("Fitur kategorikal di-one-hot-encode.")

features_df = pd.concat([df_numerik_scaled, df_kategorikal_encoded], axis=1)
print(f"Total fitur untuk model: {len(features_df.columns)}")

# --- Langkah 4: Membangun Model Autoencoder ---
print("\nLangkah 4: Membangun model Autoencoder...")
input_dim = len(features_df.columns) 
embedding_dim = 16 

print(f"Input dimension untuk model: {input_dim}")
print(f"Embedding dimension: {embedding_dim}")

encoder_input = tf.keras.layers.Input(shape=(input_dim,))
e = tf.keras.layers.Dense(128, activation='relu')(encoder_input)
e = tf.keras.layers.Dense(64, activation='relu')(e)
encoder_output = tf.keras.layers.Dense(embedding_dim, activation='relu')(e)
encoder = tf.keras.Model(encoder_input, encoder_output, name='encoder')

decoder_input = tf.keras.layers.Input(shape=(embedding_dim,))
d = tf.keras.layers.Dense(64, activation='relu')(decoder_input)
d = tf.keras.layers.Dense(128, activation='relu')(d)
decoder_output = tf.keras.layers.Dense(input_dim, activation='sigmoid')(d)
decoder = tf.keras.Model(decoder_input, decoder_output, name='decoder')

autoencoder_input = tf.keras.layers.Input(shape=(input_dim,))
encoded = encoder(autoencoder_input)
decoded = decoder(encoded)
autoencoder = tf.keras.Model(autoencoder_input, decoded, name='autoencoder')
autoencoder.compile(optimizer='adam', loss='mse')

# --- Langkah 5: Melatih Model ---
print("\nLangkah 5: Melatih model Autoencoder...")
# --- PERBAIKAN KODE ADA DI BARIS BERIKUT ---
# Secara eksplisit mengubah tipe data menjadi 'float32' yang didukung penuh oleh TensorFlow
normalized_features = features_df.values.astype('float32')
# --- AKHIR PERBAIKAN ---

autoencoder.fit(
    normalized_features,
    normalized_features,
    epochs=100,
    batch_size=32,
    shuffle=True,
    validation_split=0.1,
    verbose=0
)
print("Pelatihan model selesai.")

# --- Langkah 6 & 7: Membuat Aset dan Konversi ---
print("\nLangkah 6 & 7: Membuat aset dan konversi ke TFLite...")
all_embeddings = encoder.predict(normalized_features)
embeddings_list = all_embeddings.tolist()
with open(os.path.join(ASSETS_DIR, 'all_embeddings.json'), 'w') as f:
    json.dump(embeddings_list, f)

# Perlu menggabungkan df dengan features_df untuk mapping lokasi_id
df_for_mapping = df[['lokasi_id']].copy()
locations_map = {str(row['lokasi_id']): i for i, row in df_for_mapping.iterrows()}
with open(os.path.join(ASSETS_DIR, 'locations_map.json'), 'w') as f:
    json.dump(locations_map, f)

converter = tf.lite.TFLiteConverter.from_keras_model(encoder)
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS
]
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
with open(os.path.join(ASSETS_DIR, 'encoder_model.tflite'), 'wb') as f:
    f.write(tflite_model)

print("\n--- SEMUA ASET BERHASIL DIBUAT ULANG DENGAN PERBAIKAN ---")