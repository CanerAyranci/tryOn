# AR-Glove: Real-Time Hand Tracking & 3D Virtual Try-On

AR-Glove is a high-performance Augmented Reality (AR) application built with **Flutter** and **MediaPipe**. It overlays a custom-rigged 3D gauntlet/glove onto a user's hand in real-time. The project bridges the gap between machine learning inference and 3D computer graphics, optimized for on-device mobile performance.

## 🚀 Key Features
- **Real-Time Hand Tracking:** Utilizes Google MediaPipe for 21-point landmark detection.
- **Dynamic 3D Overlay:** Seamless 3D rendering using Three.js within a Flutter WebView.
- **Skeleton-Based Rigging:** 15-joint bone system allowing the virtual glove to mimic finger flexion.
- **On-Device Optimization:** Latency-optimized pipeline (<30ms) without cloud dependency.

---

## 🛠 Technical Implementation

### 1. The Pipeline
1. **Camera Stream:** Raw pixels are captured via Flutter's camera plugin.
2. **Landmark Detection:** MediaPipe identifies 21 (x, y, z) coordinates.
3. **Data Stabilization:** A Low-Pass Filter is applied to remove sensor noise.
4. **Coordinate Mapping:** 2D landmarks are projected into a 3D frustum using Camera FOV.
5. **Bone Manipulation:** Euclidean distances between finger joints are mapped to 3D bone rotations.

### 2. Mathematical Optimizations
To ensure stability and realism, the following mathematical models were implemented:

#### A. Jitter Stabilization (Low-Pass Filter)
Raw ML data often contains noise. We use a smoothing factor ($\alpha = 0.2$) to ensure fluid movement:
$$P_{smoothed} = P_{prev} + (P_{current} - P_{prev}) \times 0.2$$

#### B. Hand Orientation (Basis Matrix)
The model's rotation is determined by calculating a basis matrix from the hand landmarks:
- **Up Vector ($\vec{u}$):** Vector from Wrist (0) to Middle Finger Base (9).
- **Side Vector ($\vec{s}$):** Vector from Index Base (5) to Pinky Base (17).
- **Normal Vector ($\vec{n}$):** $\vec{u} \times \vec{s}$ (The vector pointing out of the palm).

#### C. Dynamic Scaling
We maintain a 1:1 scale ratio regardless of distance from the camera by measuring the distance between landmark 5 and 17.

---

## 📊 Performance Benchmarks

### Optimization Impact
| Feature | Without Optimization | With AR-Glove Optimization | Result |
| :--- | :--- | :--- | :--- |
| **Stability** | High Jitter / Shaking | Low-Pass Filtering | 85% Noise Reduction |
| **Depth** | Static Scaling | FOV-Aware Scaling | Accurate Overlay at Depth |
| **Realism** | Static 3D Mesh | 15-Bone Armature Rig | Realistic Finger Flexion |
| **Latency** | Cloud Inference | On-Device GPU Inference | ~27ms End-to-End |

### Latency Breakdown
| Component | Latency (ms) |
| :--- | :--- |
| Camera Feed Acquisition | 5ms |
| MediaPipe ML Inference | 12ms |
| Coordinate Transformation | 2ms |
| WebGL Rendering (Three.js) | 8ms |
| **Total Latency** | **27ms** |

---

## 🦴 Blender Rigging (Armature)
The 3D model must be rigged with the following bone naming convention to sync with the detection engine:

| Finger | Bones |
| :--- | :--- |
| **Thumb** | `Thumb_01`, `Thumb_02`, `Thumb_03` |
| **Index** | `Index_01`, `Index_02`, `Index_03` |
| **Middle** | `Middle_01`, `Middle_02`, `Middle_03` |
| **Ring** | `Ring_01`, `Ring_02`, `Ring_03` |
| **Pinky** | `Pinky_01`, `Pinky_02`, `Pinky_03` |

---

## 🛠 Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/Proje.git
   ```
2. **Install Flutter Dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the application:**
   ```bash
   flutter run --release
   ```
   *Note: Real-time ML performance is best tested in Release mode.*

## 📄 References
- [1] Google MediaPipe Hand Landmarker.
- [2] Three.js 3D Engine.
- [3] Horn & Schunck, "Determining Optical Flow" (1981).

---
Developed by **Caner Ayrancı** as part of the Digital Image Processing Project at Fırat University.
