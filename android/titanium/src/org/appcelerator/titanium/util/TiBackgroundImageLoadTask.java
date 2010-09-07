/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
package org.appcelerator.titanium.util;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.ref.SoftReference;
import java.util.concurrent.RejectedExecutionException;

import org.appcelerator.titanium.TiContext;
import org.appcelerator.titanium.TiDimension;
import org.appcelerator.titanium.cache.TiCacheManager;
import org.appcelerator.titanium.cache.TiCacheManager.TiCacheCallback;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.os.AsyncTask;


/**
 *
 * @author dthorp
 *
 * Overload onPostExecution(Drawable d) to handle the result.
 *
 */
public abstract class TiBackgroundImageLoadTask
	extends AsyncTask<String, Long, Drawable>
{
	private static final String LCAT = "TiBackgroundImageLoadTask";
	private static final boolean DBG = TiConfig.LOGD;

	protected SoftReference<TiContext> softTiContext;
	protected TiDimension imageHeight;
	protected TiDimension imageWidth;

	private String url;

	public TiBackgroundImageLoadTask(TiContext tiContext, TiDimension imageWidth, TiDimension imageHeight)
	{
		this.softTiContext = new SoftReference<TiContext>(tiContext);
		this.imageWidth = imageWidth;
		this.imageHeight = imageHeight;
	}

	@Override
	protected Drawable doInBackground(String... arg) {

		final AsyncResult result = new AsyncResult();
		final TiContext context = softTiContext.get();
		if (context == null) {
			if (DBG) {
				Log.d(LCAT, "doInBackground exiting early because context already gc'd");
			}
			return null;
		}

		TiCacheManager cache = context.getTiApp().getRemoteImageCache();

		url = context.resolveUrl(null, arg[0]);

		cache.get(url, new TiCacheCallback() {
			
			@Override
			public void fileReady(File f) 
			{
				boolean retry = true;
				int retryCount = 3;

				while(retry) {
					retry = false;

					try {
						
						InputStream is = null;
						try {
							is = new FileInputStream(f);
							
							BitmapFactory.Options bmo= new BitmapFactory.Options();
							bmo.inJustDecodeBounds = true;
							
							Bitmap b = BitmapFactory.decodeStream(is,null,bmo);
							is.close();
							is = null;
				
							if (bmo.outWidth > 0 && bmo.outHeight > 0) {
								is = new FileInputStream(f);
								bmo.inJustDecodeBounds = false;
								int srcWidth = bmo.outWidth;
								int srcHeight = bmo.outHeight;
								int destWidth = srcWidth;
								int destHeight = srcHeight;
								if (imageWidth != null) {
									if (!imageWidth.isUnitAuto()) {
										destWidth = imageWidth.getAsPixels();
									}
								} else {
									destWidth = context.getActivity().getWindow().getDecorView().getWidth();
								}
								if (imageHeight != null) {
									if (!imageHeight.isUnitAuto()) {
										destHeight = imageHeight.getAsPixels();
									}
								} else {
									destHeight = (int)(((float) srcHeight / (float) srcWidth)*(float)destWidth);
								}
								
								bmo.inSampleSize = Math.max(srcWidth/destWidth,srcHeight/destHeight);
								
								b = BitmapFactory.decodeStream(is, null, bmo);
								Bitmap sb = Bitmap.createScaledBitmap(b, destWidth, destHeight, true);
								b.recycle();
								b = null;
								result.setResult(new BitmapDrawable(sb));
							}
						} catch (IOException e) {
							e.printStackTrace();
						} catch (Throwable t) {
							t.printStackTrace();
						}

					} catch (OutOfMemoryError e) {
						Log.e(LCAT, "Not enough memory left to load image: " + url + " : " + e.getMessage());
						retryCount -= 1;
						if (retryCount > 0) {
							retry = true;
							Log.i(LCAT, "Signalling a GC, will retry load.");
							System.gc(); // See if we can force a compaction
							try {
								Thread.sleep(1000);
							} catch (InterruptedException ie) {
								// Ignore
							}
							Log.i(LCAT, "Retry #" + (3 - retryCount) + " for " + url);
						}
					}
				}
			}
			
			@Override
			public void error(Throwable t) {
				Log.e(LCAT, "Failed getting image. " + t.getMessage(), t);
				result.setResult(null); // maybe return broken image?
			}
		});

		return (Drawable) result.getResult();
	}

	public void load(String url) {
		try {
			execute(url);
		} catch (RejectedExecutionException e) {
			Log.w(LCAT, "Thread pool rejected attempt to load image: " + url);
			Log.w(LCAT, "ADD Handler for retry");
		}
	}
}
