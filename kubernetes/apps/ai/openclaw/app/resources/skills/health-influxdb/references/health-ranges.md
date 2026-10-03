# Health Ranges & Coaching Thresholds

## Available Measurements

Core metrics: `heart_rate`, `resting_heart_rate`, `heart_rate_variability`, `sleep_analysis`, `step_count`, `apple_exercise_time`, `vo2_max`, `respiratory_rate`

Activity: `active_energy`, `basal_energy_burned`, `flights_climbed`, `walking_running_distance`, `walking_speed`, `walking_step_length`

Walking quality: `walking_asymmetry_percentage`, `walking_double_support_percentage`, `walking_heart_rate_average`

Nutrition: `dietary_energy`, `protein`, `carbohydrates`, `total_fat`, `fiber`, `dietary_sugar`, `calcium`, `iron`, `potassium`, `sodium`, `vitamin_c`

Other: `weight_body_mass`, `mindful_minutes`, `environmental_audio_exposure`, `headphone_audio_exposure`

## Normal Ranges

| Metric | Good | Warning | Alert |
|--------|------|---------|-------|
| Sleep (inBed) | 7-9h | 6-7h | <6h |
| Resting HR | 50-70 | 70-80 | >80 |
| HRV (SDNN) | >40ms | 20-40ms | <20ms |
| Steps | >8000 | 5000-8000 | <5000 |
| Exercise | 30-60min | 15-30min | <15min |

## Burnout Indicators

Flag when 3+ of these occur together:
- Sleep <6h for 3+ consecutive days
- Resting HR elevated >10% from baseline
- HRV dropped >20% from baseline
- High commit/activity volume (check GitHub)
- Exercise >90min (overtraining)

## Coaching Prompts

**Morning (8:30am):**
- Query last night's sleep + HRV
- Check today's calendar load
- Recommend: workout intensity, work limits, wind-down target

**Evening (5pm):**
- Query today's activity + steps
- Calculate weekly sleep debt
- Recommend: recovery activities, bedtime target, tomorrow readiness
