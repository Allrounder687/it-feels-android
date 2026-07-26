package com.itfeels.music


import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.pixelplayer.saavn.pixel_player_saavn.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MusicWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                
                val title = widgetData.getString("title", "No Song Playing")
                val artist = widgetData.getString("artist", "It Feels Music")

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                // Pending intent to open the app
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
                
                // Play/Pause button
                val playIntent = HomeWidgetBackgroundIntent.getBroadcast(context, android.net.Uri.parse("myAppWidget://playpause"))
                setOnClickPendingIntent(R.id.widget_play_btn, playIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
