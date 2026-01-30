package com.molicaljeroni.soca

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.app.PendingIntent
import android.content.Intent
import android.view.View
import android.graphics.Color

class SocaWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_agenda).apply {
                // Open App on Click
                val intent = Intent(context, MainActivity::class.java)
                intent.action = Intent.ACTION_VIEW
                intent.data = Uri.parse("soca://tasks")
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.agenda_title, pendingIntent)

                // Populate Agenda Data
                var hasTasks = false
                for (i in 0..2) {
                    val title = widgetData.getString("task_title_$i", null)
                    val description = widgetData.getString("task_desc_$i", null)
                    val price = widgetData.getString("task_price_$i", null)
                    val colorHex = widgetData.getString("task_color_$i", "#4CAF50")
                    
                    val containerId = when(i) {
                        0 -> R.id.task_container_0
                        1 -> R.id.task_container_1
                        2 -> R.id.task_container_2
                        else -> 0
                    }
                    val titleId = when(i) {
                        0 -> R.id.task_title_0
                        1 -> R.id.task_title_1
                        2 -> R.id.task_title_2
                        else -> 0
                    }
                    val descId = when(i) {
                        0 -> R.id.task_date_0
                        1 -> R.id.task_date_1
                        2 -> R.id.task_date_2
                        else -> 0
                    }
                    val priceId = when(i) {
                        0 -> R.id.task_price_0
                        1 -> R.id.task_price_1
                        2 -> R.id.task_price_2
                        else -> 0
                    }
                    val indicatorId = when(i) {
                        0 -> R.id.task_indicator_0
                        1 -> R.id.task_indicator_1
                        2 -> R.id.task_indicator_2
                        else -> 0
                    }

                    if (title != null) {
                        setViewVisibility(containerId, View.VISIBLE)
                        setTextViewText(titleId, title)
                        setTextViewText(descId, description ?: "")
                        setTextViewText(priceId, price ?: "")
                        
                        // Set indicator color
                        try {
                            setInt(indicatorId, "setBackgroundColor", Color.parseColor(colorHex))
                            // Set price text color to match
                            setTextColor(priceId, Color.parseColor(colorHex))
                        } catch (e: Exception) {
                            setInt(indicatorId, "setBackgroundColor", Color.parseColor("#4CAF50"))
                        }
                        
                        hasTasks = true
                    } else {
                        setViewVisibility(containerId, View.GONE)
                    }
                }
                
                if (hasTasks) {
                     setViewVisibility(R.id.empty_view, View.GONE)
                } else {
                     setViewVisibility(R.id.empty_view, View.VISIBLE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class SocaStatusWidgetProvider : HomeWidgetProvider() {
     override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            // Check for alert to swap background
            val alert = widgetData.getString("weather_alert", null)
            val layoutRes = R.layout.widget_status
            
            val views = RemoteViews(context.packageName, layoutRes).apply {
                // Set background based on alert
                if (alert != null && alert.isNotEmpty()) {
                    setInt(R.id.widget_status_root, "setBackgroundResource", R.drawable.widget_background_alert)
                } else {
                    setInt(R.id.widget_status_root, "setBackgroundResource", R.drawable.widget_background)
                }
                
                // Open App on Click
                val intent = Intent(context, MainActivity::class.java)
                intent.action = Intent.ACTION_VIEW
                intent.data = Uri.parse("soca://climate")
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    1,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.weather_temp, pendingIntent)
                
                // Weather Data
                val temp = widgetData.getString("weather_temp", "--")
                val humidity = widgetData.getString("weather_humidity", "--")
                val wind = widgetData.getString("weather_wind", "--")
                val et0 = widgetData.getString("weather_et0", "--")
                val advice = widgetData.getString("weather_advice", "Carregant...")
                val adviceColor = widgetData.getString("weather_advice_color", "#4CAF50")
                
                setTextViewText(R.id.weather_temp, "$temp°C")
                setTextViewText(R.id.weather_humidity, "💧$humidity%")
                setTextViewText(R.id.weather_wind, "💨$wind km/h")
                setTextViewText(R.id.weather_et0, "☀️ET0: $et0")
                setTextViewText(R.id.irrigation_advice, advice)
                
                // Set advice background color
                try {
                    setInt(R.id.irrigation_advice, "setBackgroundColor", Color.parseColor(adviceColor))
                } catch (e: Exception) {
                    // Fallback
                }
                
                // Tree Irrigation Status
                val treeLedColor = widgetData.getString("tree_led_color", "green")
                val treeStatusText = widgetData.getString("tree_status_text", "Tots els arbres OK")
                
                setTextViewText(R.id.tree_status_text, treeStatusText)
                
                val ledColorInt = when(treeLedColor) {
                    "red" -> Color.parseColor("#EF5350")
                    "amber" -> Color.parseColor("#FFC107")
                    else -> Color.parseColor("#4CAF50")
                }
                setInt(R.id.tree_led, "setColorFilter", ledColorInt)
                
                // Alert Banner
                if (alert != null && alert.isNotEmpty()) {
                    setViewVisibility(R.id.alert_banner, View.VISIBLE)
                    setTextViewText(R.id.alert_banner, "⚠️ $alert")
                } else {
                    setViewVisibility(R.id.alert_banner, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
