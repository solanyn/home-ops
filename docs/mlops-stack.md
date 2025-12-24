# MLOps Stack Architecture & Portfolio Projects

## Experiment Tracking & Model Management

### Tool Selection Rationale

**Experiment Tracking:** TensorBoard
- Portable event files (protocol buffers), zero vendor lock-in
- Superior neural network visualizations (histograms, embeddings, graphs)
- Lightweight, works locally or in Kubernetes
- Tradeoff: Manual experiment/run management required
- Dismissed: MLflow, ClearML, W&B (vendor/platform lock-in or excessive complexity for homelab)

**Model Versioning:** DVC + Git
- Git-native workflow for reproducibility and lineage tracking
- S3/filesystem backend compatibility
- Tracks pipeline definition, hyperparameters, metrics
- No duplicate storage (DVC tracks pipeline, not model binaries)

**Model Registry (future, if needed):** Kubeflow Model Registry
- CNCF-governed (aligned with Kubeflow choice)
- Seamless KServe integration for serving
- Optional addition when managing 5+ production models
- Does not replace DVC; complements it (Git history + UI promotion)

**Model Packaging & Distribution:** KitOps (exploring)
- OCI artifact packaging for reproducibility/audit trails
- Standardized ML asset distribution
- Currently lacks direct KServe integration; requires extraction bridge to S3
- Decision: Defer until validated as necessary for supply chain governance needs

**Infrastructure & Serving:** Modal
- Training orchestration (batch jobs)
- On-demand inference (pay-per-use, scales to zero)
- Runs outside Kubeflow cluster (freedom from platform constraints)
- Integrates with TensorBoard, DVC, S3 via standard APIs
- Eliminates need for KServe (high overhead for experimentation/portfolio projects)

### Architecture Diagram
```
Batch Training Pipeline
  Modal training job (nightly)
  ├─ Logs metrics → TensorBoard event files (S3)
  ├─ Logs hyperparams + metadata → metadata.json
  └─ Saves model → S3

DVC tracks in Git
  ├─ Pipeline definition (dvc.yaml)
  ├─ Metrics snapshot (metrics.json)
  └─ .dvc files for reproducibility

On-Demand Inference
  Web App (FastAPI backend)
  └─ Modal inference function (GPU on-demand)
      └─ Downloads model from S3
      └─ Runs inference
      └─ Returns results
```

### Key Decisions
1. **DVC for versioning, TensorBoard for visualization:** Separate concerns, no redundancy
2. **Avoid central experiment/model registry initially:** Git + TensorBoard sufficient for homelab scale
3. **Modal for both training and inference:** Unified platform, no cold-start overhead
4. **Skip KServe:** Overkill for experimentation; Modal on-demand better for portfolio
5. **Web app for interactive demos:** Shows full-stack skills, not just ML
6. **KitOps deferred:** Evaluate after understanding full deployment and governance requirements

---

## Portfolio Project: CatML (Cat Behavior & Habit Analysis)

### Project Goal
Build a comprehensive ML system for cat behavior tracking, analysis, and prediction. Serve as public portfolio demonstrating MLOps pipeline, multiple ML domains, and practical utility.

### Components

#### 1. Behavior Classification
**What:** Classify cat activities from video frames
- Behaviors: {sleeping, eating, playing, grooming, scratching, hunting, using_litter_box}
- Model: Fine-tuned ResNet/ViT or YOLO behavior classifier
- TensorBoard metrics: Confusion matrix, per-class accuracy, loss curves
- Output: Real-time behavior inference

#### 2. Pose Estimation & Comfort Assessment
**What:** Estimate cat posture and infer comfort level
- Adapted pose estimation (MediaPipe, custom YOLO-Pose, or similar)
- Classify postures: {relaxed, stressed, in_pain, alert, playful}
- Health indicator: Unusual postures may indicate injury or illness
- TensorBoard metrics: Pose accuracy, comfort distribution over time

#### 3. Habit Prediction
**What:** Time series analysis of cat activity patterns
- Predict when cat will next use litter box, eat, or nap
- Circadian pattern analysis (activity by hour of day, day of week)
- Anomaly detection (departure from normal patterns)
- TensorBoard metrics: Prediction accuracy, activity entropy, temporal heatmaps

### Data Pipeline

#### Acquisition
- **Cameras:** 5x ESP32-CAM modules (1 per room) (~$60-75 total)
- **Placement:** Panoramic or focused on high-activity areas (litter box, feeding area, sleeping spots)
- **Storage:** Continuous to NAS-backed S3 (unlimited storage/bandwidth)
- **Retention:** Keep all video (no storage constraints with local NAS)

#### Processing
```
Continuous video (S3)
  ├─ Nightly batch via Modal
  ├─ Frame extraction (every N seconds)
  ├─ YOLOv8 cat detection + cropping
  ├─ Behavior classifier inference
  ├─ Pose estimator inference
  └─ Aggregate metrics → TensorBoard + DVC
```

#### Retraining Schedule
- Daily: New behavior/pose classification on fresh frames
- Weekly: Retrain time series (habit predictor) with accumulated activity logs
- Log all metrics to TensorBoard; track models via DVC

### Deployment

#### Data Ingestion: ESP32-CAM Setup (Recommended for Homelab)

**ESP32-CAM → RTSP → ffmpeg (Kubernetes Pod)**

**Hardware:**
- **ESP32-CAM Module** (~$10-15 on Amazon/AliExpress)
- **USB-to-UART Cable** for programming (~$5)
- **5V Power Supply** (USB or dedicated)
- **Optional:** OV2640 camera module upgrade if needed

**Setup Steps:**

1. **Install Arduino IDE and ESP32 Support**
   ```bash
   # Add board manager URL in Arduino IDE:
   # https://dl.espressif.com/dl/package_esp32_index.json

   # Install: esp32 by Espressif Systems
   ```

2. **Flash ESP32-CAM with RTSP Firmware (Optimized Settings)**

   **Optimal Camera Settings for CatML:**
   - **Resolution:** 1600x1200 (UXGA) - maximizes image quality for pose/behavior detection
   - **Frame Rate:** 5 FPS - optimal balance between data richness and Modal processing cost
   - **JPEG Quality:** 10 - high quality (low compression) to preserve behavior details
   - **Why 5 FPS?** Cat behaviors change slowly. 5 FPS captures enough frames for habit analysis without overwhelming Modal processing costs (5 cameras × 5 FPS = 2.16M frames/day = ~$20/day compute)

   ```cpp
   // Use this sketch or similar RTSP server project
   // https://github.com/geekstergit/Arduino-esp32-RTSP-server

   #include "esp_camera.h"
   #include "rtsp_server.h"

   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";

   void setup() {
     Serial.begin(115200);

     // Initialize camera with optimized settings
     camera_config_t config;
     config.ledc_channel = LEDC_CHANNEL_0;
     config.ledc_freq_hz = 20000;
     config.pin_d0 = Y2_GPIO_NUM;
     config.pin_d1 = Y3_GPIO_NUM;
     config.pin_d2 = Y4_GPIO_NUM;
     config.pin_d3 = Y5_GPIO_NUM;
     config.pin_d4 = Y6_GPIO_NUM;
     config.pin_d5 = Y7_GPIO_NUM;
     config.pin_d6 = Y8_GPIO_NUM;
     config.pin_d7 = Y9_GPIO_NUM;
     config.pin_xclk = XCLK_GPIO_NUM;
     config.pin_pclk = PCLK_GPIO_NUM;
     config.pin_vsync = VSYNC_GPIO_NUM;
     config.pin_href = HREF_GPIO_NUM;
     config.pin_scc = SIOD_GPIO_NUM;
     config.pin_sda = SIOC_GPIO_NUM;
     config.pin_pwdn = PWDN_GPIO_NUM;
     config.pin_reset = RESET_GPIO_NUM;
     config.xclk_freq_hz = 20000000;      // Max clock for image quality
     config.frame_size = FRAMESIZE_UXGA;  // 1600x1200 maximum resolution
     config.jpeg_quality = 10;            // High quality (low compression)
     config.fb_count = 1;
     config.pixel_format = PIXFORMAT_JPEG;

     esp_err_t err = esp_camera_init(&config);
     if (err != ESP_OK) {
       Serial.printf("Camera init failed with error 0x%x", err);
       return;
     }

     // Optimize sensor settings
     sensor_t *s = esp_camera_sensor_get();
     s->set_framesize(s, FRAMESIZE_UXGA);
     s->set_quality(s, 10);      // Quality 0-63 (10 = high quality)
     s->set_brightness(s, 0);    // -2 to 2
     s->set_contrast(s, 0);      // -2 to 2
     s->set_saturation(s, 0);    // -2 to 2
     s->set_awb_gain(s, 1);      // Auto white balance
     s->set_wb_mode(s, 0);       // White balance mode

     // Connect to WiFi
     WiFi.begin(ssid, password);
     while (WiFi.status() != WL_CONNECTED) delay(500);

     Serial.print("Camera IP: ");
     Serial.println(WiFi.localIP());

     // Start RTSP server
     rtsp_server_init();
   }
   ```

3. **Power and Test**
   - Connect 5V power supply to ESP32-CAM
   - Verify IP address via Serial monitor
   - Test RTSP stream: `rtsp://<ESP32_IP>:554/live`

4. **Multi-Camera Kubernetes Deployment (5 cameras)**

   Deploy one ffmpeg pod per camera to record all 5 streams in parallel:

   ```yaml
   # Camera 1 - Living Room
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: cat-camera-recorder-1
   spec:
     replicas: 1
     template:
       metadata:
         labels:
           camera: cat-camera-1
       spec:
         containers:
         - name: ffmpeg
           image: jrottenberg/ffmpeg:latest
           args:
             - -rtsp_transport
             - tcp
             - -i
             - "rtsp://192.168.1.50:554/live"  # Camera 1 IP
             - -c:v
             - libx264
             - -preset
             - veryfast
             - -crf
             - "28"
             - -segment_time
             - "300"
             - "s3://bucket/cat-camera-1/chunk-%Y%m%d-%H%M%S.mp4"
           env:
             - name: AWS_ACCESS_KEY_ID
               valueFrom:
                 secretKeyRef:
                   name: s3-credentials
                   key: access-key
             - name: AWS_SECRET_ACCESS_KEY
               valueFrom:
                 secretKeyRef:
                   name: s3-credentials
                   key: secret-key
   ---
   # Camera 2 - Bedroom
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: cat-camera-recorder-2
   spec:
     replicas: 1
     template:
       metadata:
         labels:
           camera: cat-camera-2
       spec:
         containers:
         - name: ffmpeg
           image: jrottenberg/ffmpeg:latest
           args:
             - -rtsp_transport
             - tcp
             - -i
             - "rtsp://192.168.1.51:554/live"  # Camera 2 IP
             - -c:v
             - libx264
             - -preset
             - veryfast
             - -crf
             - "28"
             - -segment_time
             - "300"
             - "s3://bucket/cat-camera-2/chunk-%Y%m%d-%H%M%S.mp4"
           env:
             - name: AWS_ACCESS_KEY_ID
               valueFrom:
                 secretKeyRef:
                   name: s3-credentials
                   key: access-key
             - name: AWS_SECRET_ACCESS_KEY
               valueFrom:
                 secretKeyRef:
                   name: s3-credentials
                   key: secret-key
   ---
   # Repeat for cameras 3, 4, 5 with different IPs and S3 paths
   # Camera 3: 192.168.1.52 → s3://bucket/cat-camera-3/
   # Camera 4: 192.168.1.53 → s3://bucket/cat-camera-4/
   # Camera 5: 192.168.1.54 → s3://bucket/cat-camera-5/
   ```

   **Storage Layout:**
   ```
   S3 Bucket Layout:
   bucket/
   ├─ cat-camera-1/  (Living Room)
   │  ├─ chunk-20250110-120000.mp4
   │  ├─ chunk-20250110-120500.mp4
   │  └─ ...
   ├─ cat-camera-2/  (Bedroom)
   │  └─ ...
   ├─ cat-camera-3/  (Kitchen)
   │  └─ ...
   ├─ cat-camera-4/  (Cat Room 1)
   │  └─ ...
   └─ cat-camera-5/  (Cat Room 2)
      └─ ...
   ```

**Advantages of ESP32-CAM:**
- ✅ Very cheap ($12-15 each × 5 = $75 total hardware)
- ✅ Low power consumption (5V, <200mA)
- ✅ Native WiFi (no ethernet needed)
- ✅ Open firmware (full control)
- ✅ Scales to 5+ cameras trivially
- ✅ Maximum resolution (1600x1200) for behavior/pose detection

**Disadvantages:**
- ⚠️ WiFi reliability (unlike wired IP cameras, depends on network stability)
- ⚠️ Limited night vision (no IR LED)
- ⚠️ Requires initial Arduino firmware flashing setup
- ⚠️ ~5 FPS max for high resolution (not suitable for high frame rate video)

**Cost Comparison:**
| Option | Cost | Resolution | Power | Setup |
|--------|------|-----------|-------|-------|
| **ESP32-CAM** | $10-20 | 1600x1200 | 5V USB | Moderate |
| **Budget IP Camera** | $40-80 | 1080p+ | PoE/12V | Easy |
| **Enterprise IP Camera** | $200+ | 1080p+ | PoE | Easy |

**Recommendation:** Start with ESP32-CAM for lowest cost and fastest iteration. Upgrade to IP camera later if needed for better reliability or resolution.

---

#### Alternative: Traditional IP Camera
**IP Camera → RTSP → ffmpeg (Kubernetes Pod)**
- Continuous video stream from commercial IP camera
- ffmpeg compresses and chunks to NAS S3 (5-minute segments)
- Retention: Unlimited (no cloud storage costs)
- Cost: Camera only ($40-200+ each) + no storage costs
- **Trade-off:** More reliable and higher resolution than ESP32, but higher initial cost and no WiFi convenience

```yaml
# Kubernetes Deployment for camera recording
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cat-camera-recorder
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: ffmpeg
        image: jrottenberg/ffmpeg:latest
        args:
          - -rtsp_transport
          - tcp
          - -i
          - "rtsp://CAMERA_IP:554/stream"  # From ONVIF discovery
          - -c:v
          - libx264
          - -preset
          - veryfast
          - -crf
          - "28"
          - -segment_time
          - "300"
          - "s3://bucket/cat-camera/$(date +%s)-%03d.mp4"
```

#### Batch Training Pipeline
**Modal job (nightly)**
- Pulls new video chunks from S3
- Extracts frames, runs detection and classification
- Logs metrics to TensorBoard event files in S3
- Saves trained models to S3
- Commits metrics to DVC in Git

#### Public-Facing Components

1. **TensorBoard Dashboard** (served via public link or self-hosted)
   - Behavior accuracy (confusion matrix)
   - Activity distribution by time (heatmaps)
   - Peak playing time, sleep duration, movement patterns
   - Anomaly scores and detection examples
   - Pose estimation accuracy
   - Updated nightly with latest training runs

2. **Interactive Web App** (FastAPI + React/Vue frontend)
   - Users upload cat photo or video clip
   - Backend calls Modal inference function
   - Returns: `{behavior, confidence, pose, comfort_score, anomaly_flag}`
   - Real-time inference via on-demand Modal GPU
   - Can be hosted on VPS or simple Kubernetes service

3. **Monthly Habit Report** (generated from batch data)
   - "Whiskers napped 18h, played 2h, ate 4 times"
   - Activity heatmaps and predictions
   - Anomaly summary and health insights

4. **GitHub Repository**
   - Full pipeline code (ffmpeg config, training, inference)
   - Model checkpoints (or links to S3)
   - Web app code (FastAPI + frontend)
   - DVC configuration and training logs
   - Markdown documentation (approach, dataset details, results)

### Portfolio Value

**Technical skills demonstrated:**
- **ML/CV:** Detection, classification, pose estimation, time series forecasting
- **MLOps:** TensorBoard, DVC, Git-based versioning, Modal orchestration
- **Data Engineering:** Continuous ingestion (ffmpeg), batch processing, S3 storage
- **Backend:** FastAPI, on-demand inference, integration with ML models
- **Frontend:** Interactive web app for demo/testing
- **DevOps:** Kubernetes (camera pod), containerization, CI/CD
- **Full-stack:** Training pipeline → batch metrics → inference API → web UI

**Appeal:**
- Visually engaging (people love cats)
- Technically sophisticated (full MLOps + web stack)
- Genuinely useful (monitor cat health and behavior)
- Interactive demo (users can test it)
- Reproducible and fully documented
- Demonstrates complete ML lifecycle end-to-end
- Zero vendor lock-in (all open source)

### Implementation Timeline
- **Phase 1:** Camera setup + ffmpeg Kubernetes pod (1 day)
- **Phase 2:** YOLOv8 detection, behavior classifier training (2-3 days)
- **Phase 3:** Pose estimation and comfort classification (2-3 days)
- **Phase 4:** Time series habits model (2 days)
- **Phase 5:** Modal training orchestration + TensorBoard logging (1-2 days)
- **Phase 6:** FastAPI backend + Modal inference function (1-2 days)
- **Phase 7:** Web app frontend (React/Vue) (2-3 days)
- **Phase 8:** Documentation and public release (1-2 days)
- **Total:** 12-18 days (distributed)

### Next Steps

**Phase 0: Hardware Setup**
1. Procure 5x ESP32-CAM modules + USB cables + power adapters (~$75-100)
2. Flash RTSP firmware to all 5 cameras (using Arduino IDE setup above)
3. Connect to WiFi and assign static IPs (192.168.1.50-54)
4. Test RTSP stream from each: `ffplay rtsp://192.168.1.50:554/live` etc.

**Phase 1: Data Ingestion**
5. Create NAS S3 bucket structure (cat-camera-1 through cat-camera-5)
6. Deploy ffmpeg Kubernetes pods (5 deployments, one per camera)
7. Verify chunks flowing to S3 every 5 minutes

**Phase 2: Model Development**
8. Collect 1-2 weeks of video data across all cameras
9. Select and fine-tune pre-trained behavior classification model (YOLOv8, ResNet)
10. Design DVC pipeline for reproducible training
11. Implement pose estimation model

**Phase 3: Training Pipeline**
12. Create Modal training job (nightly batch on all 5 camera feeds)
13. Configure TensorBoard logging (metrics → S3)
14. Integrate DVC for model versioning

**Phase 4: Inference & Demo**
15. Build FastAPI backend with Modal inference function
16. Create web app frontend (React/Vue, upload + display results)
17. Deploy web app (VPS or K8s service)

**Phase 5: Polish & Release**
18. Configure TensorBoard on public URL
19. Write comprehensive GitHub documentation (architecture, setup, results)
20. Create demo video showing web app + TensorBoard dashboard
21. Share portfolio link
