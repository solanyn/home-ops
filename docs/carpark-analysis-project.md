# Car Park Analysis & Occupancy Prediction Project

## Project Goal
Build a real-time parking occupancy monitoring system for the shopping centre rooftop car park visible from your apartment. Predict parking availability, estimate time to find a space, and analyze occupancy patterns. Serve as portfolio demonstrating urban analytics, computer vision for practical applications, and time series forecasting.

## Technical Components

### 1. Vehicle Detection & Space Occupancy
**What:** Detect parked vehicles and classify parking space status
- Model: YOLOv8 for vehicle detection
- Space classification: {empty, occupied, uncertain}
- Occupancy rate calculation (percentage of spaces filled)
- Grid-based heatmaps (which sections fill first?)
- TensorBoard metrics: Detection accuracy, occupancy rate, confidence scores, space-level heatmaps

### 2. Occupancy Forecasting
**What:** Predict future parking availability
- Time series model: LSTM on occupancy history
- Forecast: "In 2 hours, car park will be 85% full"
- By-section forecasting (predict which areas will fill)
- Peak hour prediction
- TensorBoard metrics: RMSE, MAE, forecast accuracy, prediction confidence

### 3. Parking Search Time Estimation
**What:** Estimate how long it takes to find a free space
- Metric: Average time from entry to occupying space
- Inputs: Current occupancy, time of day, section density, recent trend
- Output: "Expected 8-12 minutes to find a space" or "Space available immediately"
- Factors: Occupancy rate, distribution across sections, time of day
- TensorBoard metrics: Estimated vs actual search time, accuracy by occupancy level, by time of day

### 4. Anomaly Detection & Pattern Analysis
**What:** Identify unusual parking patterns
- Unexpected occupancy spikes (special event?)
- Empty-out patterns (mall closing, emergency?)
- Rush hour analysis (when do people arrive/leave?)
- Seasonal/day-of-week patterns
- TensorBoard metrics: Anomaly scores, pattern heatmaps, day comparison plots

## Data Pipeline

### Acquisition
- **Camera:** IP camera or ESP32-CAM on apartment balcony overlooking car park
- **View:** Rooftop car park (wide view to capture multiple sections)
- **Storage:** Continuous to NAS-backed S3 (unlimited)
- **Retention:** All video (track patterns over weeks/months)
- **Challenge:** Lighting (shadows, sun angle, night), perspective (angle distortion)

### Processing
```
Continuous rooftop video (S3)
  ├─ Nightly batch via Modal
  ├─ Frame extraction (every 10-15 seconds, less frequent due to static scene)
  ├─ YOLOv8 vehicle detection
  ├─ Space-level classification (occupied/empty)
  ├─ Occupancy aggregation by section and time
  ├─ Search time estimation model
  ├─ Time series forecasting
  └─ Aggregate metrics → TensorBoard + DVC
```

### Retraining Schedule
- Daily: Update occupancy counts on new footage
- Weekly: Retrain occupancy forecaster with new patterns
- Weekly: Update search time model with observed patterns
- Monthly: Analyze anomalies and pattern changes

## Deployment

### Camera Setup
- **Camera:** IP camera (wide angle) or ESP32-CAM on balcony
- **View:** Should capture entire visible car park section
- **Settings:** 1600x1200 @ 2-3 FPS (static scene needs less data)
- **Challenge:** Daylight/night transitions, shadows

**Why slower FPS:** Car park changes slowly (parking takes 1-2 min per space)

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: carpark-camera-recorder
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
          - "rtsp://192.168.1.70:554/live"  # Car park camera
          - -c:v
          - libx264
          - -preset
          - veryfast
          - -crf
          - "28"
          - -segment_time
          - "600"  # 10-minute chunks (slower changes)
          - "s3://bucket/carpark-camera/chunk-%Y%m%d-%H%M%S.mp4"
```

### Batch Training Pipeline
**Modal job (nightly)**
- Pulls video chunks from S3
- Extracts frames, runs YOLOv8 vehicle detection
- Classifies spaces (occupied/empty) per frame
- Aggregates occupancy by time and section
- Trains/updates forecasting model (LSTM)
- Estimates search time from patterns
- Logs metrics to TensorBoard
- Commits progress to DVC

## Public-Facing Components

### 1. TensorBoard Dashboard
- **Real-time occupancy:** Current % full, by section (heatmap)
- **Occupancy trends:** Hourly/daily/weekly patterns (line charts)
- **Peak hours:** When is car park busiest? (heatmap by hour/day)
- **Forecast accuracy:** Predicted vs actual occupancy (line chart)
- **Search time trends:** Average time to find space by hour/day
- **Anomalies:** Unusual patterns flagged with dates
- **Day comparisons:** Monday vs Friday, weekday vs weekend
- **Model performance:** RMSE, MAE of occupancy forecast

### 2. Interactive Web App (FastAPI + React)
- Live occupancy status ("85% full, ~200 spaces available")
- Parking search time estimate ("Expected 8-12 min to find space")
- 2-hour forecast ("At 5 PM, expect 92% occupancy")
- Heatmap showing which sections are fullest
- Historical patterns ("Friday is always busy 5-7 PM")
- Best time to go ("Emptiest 10-11 AM on weekdays")
- Alerts ("Car park near capacity")

### 3. Insights Report
- "Peak occupancy: Friday 5-6 PM (95% full)"
- "Fastest to find space: Tuesday morning (2-3 min avg)"
- "Slowest: Friday evening (15-20 min avg)"
- "Unusual pattern on Dec 24: 40% empty (holiday shopping hours)"
- "Search time correlates 0.89 with occupancy rate"

### 4. GitHub Repository
- Complete ML pipeline (detection, forecasting, search time)
- YOLOv8 model + training code
- LSTM forecasting model
- Space classification logic
- DVC configuration and training logs
- Markdown: methodology, assumptions, model performance
- Example predictions and live demo link

## Portfolio Value

**Technical skills demonstrated:**
- **Computer vision:** Vehicle detection, space classification, perspective challenges
- **Time series:** Occupancy forecasting, anomaly detection, seasonal patterns
- **Practical ML:** Real-world application with business value
- **Data science:** Feature engineering (occupancy, trends, time features), model evaluation
- **MLOps:** Continuous batch processing, monitoring, versioning

**Appeal:**
- **Practical angle** (everyone parks, relatable problem)
- **Real-world deployment** (could actually be useful for shopping centre)
- **Predictive** (forecasting is impressive)
- **Urban tech angle** (smart cities, IoT applications)
- **Monetization story** (could license to shopping centre)

**Why it's different from CatML & Birds:**
- Static/wide scene (vs moving subjects)
- Predictive focus (vs classification)
- Urban/commercial angle (vs pet/nature)
- Business application potential
- Practical value demonstration

## Implementation Timeline

- **Phase 1:** Rooftop camera setup + balcony mount (1 day)
- **Phase 2:** YOLOv8 vehicle detection + space classification (2-3 days)
- **Phase 3:** Occupancy aggregation + analysis (1-2 days)
- **Phase 4:** LSTM forecasting model (2-3 days)
- **Phase 5:** Search time estimation model (1-2 days)
- **Phase 6:** Modal pipeline + TensorBoard logging (1-2 days)
- **Phase 7:** FastAPI backend + forecasting API (1-2 days)
- **Phase 8:** Web app frontend (2-3 days)
- **Phase 9:** Documentation, insights, deployment (2 days)
- **Total:** 15-21 days (distributed, can overlap with other projects)

## Key Metrics & Formulas

### Occupancy Rate
```
occupancy_rate = occupied_spaces / total_spaces * 100
```

### Parking Search Time Estimation
```
search_time_estimate = base_time + (occupancy_rate * sensitivity_factor) + time_of_day_offset

where:
  base_time = 2 minutes (minimum, space directly available)
  sensitivity_factor = 0.2 (minutes per percent occupancy)
  time_of_day_offset = adjustment based on historical patterns

example: 80% occupancy, 5 PM peak = 2 + (80 * 0.2) + 3 = 19 minutes
```

### Forecast Model
```
LSTM input: [occupancy_history (last 24h), time_features (hour, day), recent_trend]
LSTM output: occupancy forecast for next 2, 4, 6 hours
```

## Challenges & Solutions

| Challenge | Solution |
|-----------|----------|
| **Shadows** | Augment training data with various lighting, use time-of-day context |
| **Perspective distortion** | Use homography transform to normalize perspective, or train on perspective-augmented data |
| **Night/low light** | Collect training data across lighting conditions, possibly upgrade to low-light camera |
| **Parked vehicles vs moving** | Track vehicles over frames (same position = parked) |
| **Empty spaces difficult to detect** | Detect vehicles first, assume remaining areas are empty |
| **Weather (rain, snow)** | Include weather context in model, collect diverse weather data |

## Next Steps

1. Mount IP camera (or ESP32-CAM) on apartment balcony overlooking car park
2. Test RTSP stream, verify coverage of visible car park area
3. Deploy ffmpeg Kubernetes pod
4. Collect 2-3 weeks of video data
5. Annotate frames with vehicle/space labels (10-20 samples across times)
6. Train YOLOv8 on annotated data
7. Develop space classification logic (occupied/empty)
8. Aggregate occupancy data by time (hourly averages)
9. Collect historical occupancy data (2-4 weeks) for pattern analysis
10. Train LSTM forecasting model
11. Develop search time estimation model
12. Create Modal training pipeline
13. Build FastAPI backend with forecasting endpoints
14. Create web app dashboard
15. Deploy and collect feedback
16. Write comprehensive documentation
17. Publish on GitHub with live demo

## Future Enhancements

- License plate recognition (track individual user patterns - privacy permitting)
- Integration with shopping centre systems (revenue correlation)
- Mobile app for parking guidance
- Recommendation engine ("Go now, lots of space" vs "Wait, too busy")
- Multi-floor analysis (if your view includes multiple levels)
- Weather correlation (does rain/snow affect parking patterns?)
