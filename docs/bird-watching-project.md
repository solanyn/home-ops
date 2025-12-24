# Bird Watching & Species Tracking Project

## Project Goal
Build a comprehensive bird observation system that automatically detects, identifies, and tracks bird species in your apartment area. Analyze migration patterns, population trends, and circadian activity. Serve as portfolio demonstrating wildlife ML, conservation impact, and ecological data science.

## Technical Components

### 1. Bird Detection & Species Classification
**What:** Detect birds in video frames and identify species
- Models: YOLOv8 for detection + ResNet/ViT species classifier
- Species target: 15-25 common local bird species
- Confidence scoring for each identification
- TensorBoard metrics: Detection accuracy, per-species precision/recall, confidence distributions

### 2. Population Counting & Trends
**What:** Count birds over time and track population changes
- Daily/weekly/monthly aggregation
- Species distribution (pie charts, heatmaps)
- Migration patterns (seasonal changes in species presence)
- Trend analysis (are populations stable, growing, declining?)
- TensorBoard metrics: Population counts, species frequency, temporal trends

### 3. Circadian Activity Analysis
**What:** Understand when different species are most active
- Activity by hour of day
- Activity by day of week
- Species-specific patterns (early risers, twilight active, etc.)
- Correlations (do certain species appear together?)
- TensorBoard metrics: Activity heatmaps, species co-occurrence patterns

### 4. Anomaly Detection
**What:** Detect unusual bird activity
- Unexpected species appearance (rare bird spotted!)
- Unusual timing patterns
- Population spike detection
- Potential environmental changes reflected in bird activity
- TensorBoard metrics: Anomaly scores, alerts, rare species examples

## Data Pipeline

### Acquisition
- **Cameras:** Outdoor-facing ESP32-CAM (1-2 per apartment window facing bushes)
- **Placement:** Overlooking dense vegetation/bushes where birds congregate
- **Storage:** Continuous to NAS-backed S3 (unlimited)
- **Retention:** All video (track seasonal patterns over months/years)

### Processing
```
Continuous outdoor video (S3)
  ├─ Nightly batch via Modal
  ├─ Frame extraction (every 5-10 seconds, less frequent than cat project)
  ├─ YOLOv8 bird detection + bounding boxes
  ├─ Species classifier inference
  ├─ Population aggregation
  ├─ Circadian pattern extraction
  └─ Aggregate metrics → TensorBoard + DVC
```

### Retraining Schedule
- Daily: New species detections on fresh frames
- Weekly: Retrain species classifier with new examples
- Monthly: Update population trend models
- Seasonal: Analyze migration patterns

## Deployment

### Camera Setup
- **Outdoor ESP32-CAM** (~$15, requires weatherproofing)
- **Placement:** Window or balcony overlooking vegetation
- **Settings:** Same as CatML (1600x1200 @ 5 FPS, quality=10)
- **Weatherproofing:** Plastic enclosure, roof overhang, or recessed mount

**Note:** Outdoor placement is key—birds are outside, not in apartment like cat

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bird-camera-recorder
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
          - "rtsp://192.168.1.60:554/live"  # Outdoor camera
          - -c:v
          - libx264
          - -preset
          - veryfast
          - -crf
          - "28"
          - -segment_time
          - "300"
          - "s3://bucket/bird-camera/chunk-%Y%m%d-%H%M%S.mp4"
```

### Batch Training Pipeline
**Modal job (nightly)**
- Pulls video chunks from S3
- Extracts frames, runs YOLOv8 detection
- Species classification on detected birds
- Population counting and aggregation
- Logs metrics to TensorBoard
- Tracks models with DVC

## Public-Facing Components

### 1. TensorBoard Dashboard
- Species distribution (pie chart: which species most common?)
- Activity heatmaps (when are birds most active by hour/day?)
- Population trends (how populations change over months)
- Detection accuracy metrics
- Rare bird alerts (when unusual species detected)
- Seasonal migration visualization (species presence over year)
- Detection examples (best/worst predictions)

### 2. Interactive Web App (FastAPI + React)
- Upload bird photo/video clip
- Identify species and confidence
- Query historical sightings ("How many cardinals this month?")
- View TensorBoard trends
- Export species checklist
- See rare bird alerts

### 3. Monthly Ecology Report
- "Recorded 47 bird sightings across 18 species this month"
- Migration highlights ("Warblers peak in spring migration")
- Population trends ("Robin population up 15% from last month")
- Rare/notable sightings
- Comparison with previous months/seasons

### 4. GitHub Repository
- Complete ML pipeline code
- Pre-trained models (YOLOv8, species classifier)
- Data processing scripts
- DVC configuration
- Model training logs
- Markdown: methodology, species list, ecological insights

## Portfolio Value

**Technical skills demonstrated:**
- **Computer vision:** Multi-class object detection, fine-grained classification
- **Time series:** Population trends, seasonal patterns, anomaly detection
- **Data science:** Ecological analysis, statistical patterns
- **MLOps:** Batch training, TensorBoard logging, DVC versioning
- **Domain knowledge:** Bird ecology, migration patterns, species identification

**Appeal:**
- Unique angle (birds, not just cats/cars)
- Ecological/conservation angle (real-world impact)
- Temporal analysis (trends over months/years, more sophisticated)
- Species detection (fine-grained classification harder than behavior)
- Publicly shareable results (people care about birds in their area)

**Why it's different from CatML:**
- Outdoor/wildlife focus (vs indoor pet)
- Population trends (vs individual behavior)
- Seasonal/migration patterns (vs daily habits)
- Ecological impact narrative

## Implementation Timeline

- **Phase 1:** Outdoor camera setup + weatherproofing (1 day)
- **Phase 2:** YOLOv8 bird detection + species classifier training (3-4 days)
- **Phase 3:** Population counting + circadian analysis (2 days)
- **Phase 4:** Anomaly detection + rare bird alerts (1-2 days)
- **Phase 5:** Modal training orchestration + TensorBoard (1-2 days)
- **Phase 6:** FastAPI backend + web app (2-3 days)
- **Phase 7:** Documentation, rare sightings feature, ecology report (2 days)
- **Total:** 14-18 days (distributed, can run in parallel with CatML after Phase 1)

## Key Differences from CatML

| Aspect | CatML | Bird Watching |
|--------|-------|---------------|
| **Subject** | Indoor pet (fixed location) | Outdoor wildlife (mobile) |
| **Detection** | Single object (cat) | Multiple objects (many birds) |
| **Classification** | 7 behaviors | 15-25 species |
| **Time horizon** | Daily habits | Seasonal patterns |
| **Uniqueness** | Personal (your cat) | Ecological (conservation angle) |
| **Data source** | 5 indoor cameras | 1-2 outdoor cameras |

## Next Steps

1. Procure outdoor-rated ESP32-CAM + weatherproof enclosure
2. Mount on apartment balcony/window overlooking vegetation
3. Test RTSP stream
4. Deploy ffmpeg Kubernetes pod
5. Collect 2-4 weeks of baseline video data
6. Research local bird species and create training dataset
7. Fine-tune YOLOv8 for bird detection on your footage
8. Train species classification model
9. Implement population counting logic
10. Build Modal training job (circadian analysis, trends)
11. Create web app for species queries and alerts
12. Deploy public TensorBoard dashboard
13. Write ecological insights documentation
14. Publish on GitHub
