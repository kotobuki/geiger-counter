
$(document).ready(function()
{
	$('#gmcounter-viewer').visualizeGmCounter(
	{
		apiURI:[
			'http://api.pachube.com/v2/feeds/20337.json',	// mayfair
			'http://api.pachube.com/v2/feeds/397.json'		// miyasita
		]
		// visualizer: new GmVisualizer()
	});
});



/**
 *	
 *	plugin for jQuery - visualizeGmCounter
 *	
 *	@summary
 *		<www.pachube.com> に登録されているガイガーカウンターのデータを取得し、可視化しています。
 *		このソースコードは、おおまかに分けて☟4つのセクションに分かれています。
 *			+ config
 *			+ Pachubeからのデータ取得部分実装
 *			+ Visualize部分実装
 *			+ 実行
 *	
 *	@todo
 *		+ 各jsonによってmin/max値が違うけど単純にcurrent_valueを出してればいいのかな...?
 *		+ Circleの色の決定方法を決める。 サイズに意味は無いのはどうしよう（データ観測地の数にもよるかも。今試してたら30000位がちょうど良いように思った）
 *		+ Balloon内の見せ方、currentValue/Max の横棒グラフなんかを付ける？
 */
(function($){

	$.fn.visualizeGmCounter = function(config)
	{
		/**
		 *	$(elem).visualizeGmCounter() の設定
		 *	========================================================
		 *
		 *		{Array}		apiURI
		 *			+ 取得したいPachube APIのURI (json) を配列で格納します。
		 *
		 *		{Object}	visualizer
		 *			+ Pachubeから取得したデータを使ってVisualizeするClassのインスタンスです。
		 *			+ 何も指定しない場合は、このコード内の Class GmVisualizer が使用されます。
		 *			+ Pachubeからのデータ取得が終わると、 取得した全Jsonの配列を引数としてvisualizerインスタンスの draw メソッドが呼び出されます。
		 *			+ Forkする際には、このGmVisualizerを編集したり、 別のvisualizerを渡したりすると便利（かもしれません）。
		 *	
		 */
		config = $.extend(
		{
			apiURI:[],
			visualizer: undefined
		}, config);

		var target = this;



		/**
		 *	Class GmDataParser
		 *	========================================================
		 *	
		 *		@use
		 *			+ Pachubeからデータを取得して、visualizerに渡します。
		 *			
		 */
		var GmDataParser = function(){};
		GmDataParser.prototype =
		{
			/**
			 *	{Array}	aData
			 *		+ Pachubeから取得したデータ全てを配列で格納。 Visualizerの draw() の引数に渡されます。
			 */
			aData: [],

			/**
			 *	{Function}	getData
			 *		+ visualizeGmCounter定義冒頭の config.apiURI 全てのURIからデータを取得します。
			 *		+ 全てのURIからデータを貰った時点で, config.visualizer.draw に this.data を渡して実行します。
			 */
			getData: function()
			{
				var aData = this.aData;
				for(var i=0; i<config.apiURI.length; i++)
				{
					$.ajax(
					{
						url: config.apiURI[i],
						dataType : 'jsonp',
						jsonp:'callback',
						timeout: 5000,
						data: "timezone=+9",
				    	success: function(oJson)
						{
							aData.push(oJson);
							if(aData.length == config.apiURI.length)
							{
								if (config.visualizer.draw)
								{
									config.visualizer.draw(target, aData);
								}
								else
								{
									throw new Error('visualiserに draw() メソッドがありません。');
								};
							};
				    	},
				    	error: function(e)
						{
							console.log(e);
						},
						statusCode:
						{
							404: function()
							{
								console.log('invalid API URL...');
  							}
						}
					});
				};
			}
		};



		/**
		 *	Class GmVisualizer
		 *	========================================================
		 *	
		 *		@use
		 *			+ Pachubeからのデータ取得が終わると、 draw メソッドが呼び出されます。
		 *			+ JSON形式のデータのみ受け付けます。
		 *		
		 */
		var GmVisualizer = function(){};
		GmVisualizer.prototype = 
		{
			/**
			 *	{Object}	oGMap		google.maps.Mapへの参照
			 *	{Array}		aInfoWindow	google.maps.InfoWindow の配列
			 */
			oGMap: undefined,
			aInfoWindow: new Array(),
			/**
			 *	{Function}	draw
			 *		+ Pachubeからのデータ取得が終わった後、このmethodが呼ばれます。
			 *		
			 *		@params {Array}	data
			 *			config.apiURI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
			 *		
			 *		@params {Array}	data
			 *			config.apiURI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
			 */
			draw: function(elTarget, aData)
			{
				try
				{
					/**
					 *	Google Mapの初期化
					 */
					this.oGMap = new google.maps.Map(elTarget.get(0), {
						zoom: 4,
						center: new google.maps.LatLng(38.0,135.0),
						mapTypeId: google.maps.MapTypeId.ROADMAP,
						scaleControl: false,
						scrollwheel: true
					});
					/**
					 *	PachubeのデータをGmap上に配置
					 */
					this.visualize(aData);
				}
				catch(e)
				{
					throw new Error(e);
				};
			},
			/**
			 *	{Function}	visualize
			 *		
			 *		@params {Array}	aData
			 *			config.apiURI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
			 */
			visualize: function(aData)
			{
				var elBalloon = this.elBalloon;
				var oGMap = this.oGMap;

				for(var i=0; i < aData.length; i++)
				{
					var oJson = aData[i];
					if (!oJson)
					{
						continue;
					};

					/**
					 *	地図上にOverlayを置く時に使用する緯度経度
					 */
					var oGLatLng = new google.maps.LatLng(oJson.location.lat, oJson.location.lon, false);
					/**
					 *	マーカーをクリックしなくても状況がある程度一覧出来る様にcircleを用意
					 */
					var oCircle = new google.maps.Circle({
						map: oGMap,
						center: oGLatLng,
						radius: 30000,
						fillOpacity: 0.5,
						fillColor: '#ff0000',
						strokeColor: '#ff0000',
						strokeOpacity: 1,
						strokeWeight: 1,
					});
					/**
					 *	Markerを地図上に追加
					 */
					var oGMarker = new google.maps.Marker(
					{
						position: oGLatLng,
    					map: oGMap,
						title: oJson.title
					});
					oGMarker.nIndex = i;
					oGMarker.setMap(oGMap);
					/**
					 *	Markerにイベントを登録
					 */
					var fnCreateHtmlFromJson = this.createHtmlFromJson;
					var aInfoWindow = this.aInfoWindow;
					google.maps.event.addListener(oGMarker, 'click', function(oPoint)
					{
						$(aInfoWindow).each(function(j, oGWindow)
						{
							oGWindow.setMap(null);
						});
						var sNewString = fnCreateHtmlFromJson(aData[this.nIndex]);
						var oGInfoWindow = new google.maps.InfoWindow(
						{
							content: sNewString
						});
						aInfoWindow.push(oGInfoWindow);
						oGInfoWindow.open(oGMap, this);
					});
				};
			},
			/**
			 *	
			 */
			createHtmlFromJson: function(oJson)
			{
				var elBalloon = $('<div id="balloon">');
				var sNewString = new String();
				// -------------------------------------
				/**
				 *	for debugging...
				 */
				// console.log(oJson)
				// console.log("[title] "+ oJson.title);
				// console.log("[creator] "+ oJson.creator);
				// console.log("[description] "+ oJson.description);
				// console.log("[at] "+ oJson.datastreams[0].at);
				// console.log("[current_value] "+ oJson.datastreams[0].current_value);
				// console.log("[max_value] "+ oJson.datastreams[0].max_value);
				// console.log("[min_value] "+ oJson.datastreams[0].min_value);
				// console.log("------------");
				// -------------------------------------

				oJson.feed.match(/\/(\d+)\.json$/);
				var elTitle = $(
					'<h2 class="title"><span>情報提供元: </span><a href="http://www.pachube.com/feeds/'+RegExp.$1
					+ '" target="_blank">'
					+ oJson.title
					+ '</a></h2>');	//oJson.creatorを使う方がスマートだけど,Feedページに直接飛ばすのが適切
				var elDescription	= $('<p class="description">').html(oJson.description);
				var elCurrentValue 	= $('<p class="value">').html(oJson.datastreams[0].current_value);
				var elRange			= $('<span class="max"> / '+oJson.datastreams[0].max_value+'</span>');
				var elAt 		  	= $('<p class="at">')
										.html(oJson.datastreams[0].at
										.replace(/^/,'計測日: ')
										.replace(/-/g, '/')
										.replace('T', '<br />計測時間: ')
										.replace(/\.\d+\+.+?$/, ''));
				elCurrentValue.append(elRange);
				elBalloon.append(elTitle);
				elBalloon.append(elCurrentValue);
				elBalloon.append(elAt);
				elBalloon.append(elDescription);

				sNewString = elBalloon.html();
				elBalloon = null;
				return sNewString;
			}
		};




		/**
		 *	実行
		 *	========================================================
		 */
		if ( !config.visualizer )
		{
			config.visualizer = new GmVisualizer();
		};
		(new GmDataParser()).getData();
	}
})(jQuery);