
/**
 *	実行
 *	========================================================
 */
$(document).ready(function()
{
	$('#gmcounter-viewer').visualizeGmCounter(
	{
		pachubeAPIParams:[
	      {
			'tag':'sensor:type=radiation',
			'lat':35,
			'lon':139,
			'distance':2000,
			'timezone':9
	      }
		]
		// visualizer: new GmcVisualizer()
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
 *		+ 今回のケースに合った、良いVisualize方法を探す
 *		
 */
(function($){

	$.fn.visualizeGmCounter = function(config)
	{
		/**
		 *	$(elem).visualizeGmCounter() の設定
		 *	========================================================
		 *
		 *		{Array}		pachubeAPI
		 *			+ 取得したいPachube APIのURI (json) を配列で格納します。
		 *
		 *		{Object}	visualizer
		 *			+ Pachubeから取得したデータを使ってVisualizeするClassのインスタンスです。
		 *			+ 何も指定しない場合は、このコード内の Class GmcVisualizer が使用されます。
		 *			+ Pachubeからのデータ取得が終わると、 取得した全Jsonの配列を引数としてvisualizerインスタンスの draw メソッドが呼び出されます。
		 *			+ Forkする際には、このGmcVisualizerを編集したり、 別のvisualizerを渡したりすると便利（かもしれません）。
		 *	
		 */
		config = $.extend(
		{
			pachubeAPIURL:'http://api.pachube.com/v2/feeds.json',
			pachubeAPIKey:'MgztfC5Tt2fO-gqrPeokxCM2kT6MdKAS6eik0YZZ8UE', // API Key for <jsrun.it>
			pachubeAPIParams:[],
			visualizer: undefined
		}, config);

		var target = this;



		/**
		 *	Class GmcDataParser
		 *	========================================================
		 *	
		 *		@use
		 *			+ Pachubeからデータを取得して、visualizerに渡します。
		 *			
		 */
		var GmcDataParser = function(){};
		GmcDataParser.prototype =
		{
			/**
			 *	{Array}	aData
			 *		+ Pachubeから取得したデータ全てを配列で格納します。
			 *		+ 中に入るデータは, www.pachube.com/feeds/{Feed ID}.json で得られる形式のJSONです。
			 *		+ このデータは、Visualizerの draw() の引数に渡されます。
			 */
			aData: [],

			/**
			 *	{Function}	getData
			 *		+ visualizeGmCounter定義冒頭の config.pachubeAPI 全てのURIからデータを取得します。
			 *		+ 全てのURIからデータを貰った時点で, config.visualizer.draw に this.data を渡して実行します。
			 */
			getData: function()
			{
				var aData = this.aData;
				for(var i=0; i<config.pachubeAPIParams.length; i++)
				{
					config.pachubeAPIParams[i].key = config.pachubeAPIKey;
					$.ajax(
					{
						url: config.pachubeAPIURL,
						dataType : 'jsonp',
						jsonp:'callback',
						timeout: 5000,
						data: config.pachubeAPIParams[i],
				    	success: function(oJson)
						{
							aData = aData.concat(oJson.results);
							
							if(i == config.pachubeAPIParams.length)
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
								alert('invalid API URL...');
  							}
						}
					});
				};
			}
		};



		/**
		 *	Class GmcVisualizer
		 *	========================================================
		 *	
		 *		@use
		 *			+ Pachubeからのデータ取得が終わると、 draw メソッドが呼び出されます。
		 *			+ JSON形式のデータのみ受け付けます。
		 *		
		 */
		var GmcVisualizer = function(){};
		GmcVisualizer.prototype = 
		{
			/**
			 *	{Object}	oGMap		google.maps.Mapへの参照
			 *	{Array}		aGInfoWindows	google.maps.InfoWindow の配列
			 */
			oGMap: undefined,
			aGInfoWindows: new Array(),
			/**
			 *	{Function}	draw
			 *		+ Pachubeからのデータ取得が終わった後、このmethodが呼ばれます。
			 *		
			 *		@params {Array}	data
			 *			config.pachubeAPI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
			 *		
			 *		@params {Array}	data
			 *			config.pachubeAPI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
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
			 *			config.pachubeAPI で指定したPachube APIから取得した全てのJSONがこの配列に入っています。
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
					// console.log("[unit.label] "+ oJson.datastreams[0].unit.label);

					// if (oJson.datastreams[0].unit)
					// {
					// 	console.log("["+i+"][unit.symbol] "+ oJson.datastreams[0].unit.symbol);					
					// }
					// else
					// {
					// 	console.log("["+i+"]none");
					// };

					// console.log("[unit.type] "+ oJson.datastreams[0].unit.type);
					// console.log("[location.lat] "+ oJson.location.lat);
					// console.log("[location.lon] "+ oJson.location.lon);
					// console.log("------------");
					// -------------------------------------
					/**
					 *	地図上にOverlayを置く時に使用する緯度経度
					 */
					var oGLatLng = new google.maps.LatLng(oJson.location.lat, oJson.location.lon, false);
					/**
					 *	!!!: 要修正
					 *	マーカーをクリックしなくても状況がある程度一覧出来る様にcircleを用意
					 */
					// var oCircle = new google.maps.Circle(
					// {
					// 	map: oGMap,
					// 	center: oGLatLng,
					// 	radius: 30000,
					// 	fillOpacity: 0.5,
					// 	fillColor: '#ff0000',
					// 	strokeColor: '#ff0000',
					// 	strokeOpacity: 1,
					// 	strokeWeight: 1,
					// });
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
					var aGInfoWindows = this.aGInfoWindows;
					google.maps.event.addListener(oGMarker, 'click', function(oPoint)
					{
						$(aGInfoWindows).each(function(j, oGWindow)
						{
							oGWindow.setMap(null);
						});
						var sNewString = fnCreateHtmlFromJson(aData[this.nIndex]);
						var oGInfoWindow = new google.maps.InfoWindow(
						{
							content: sNewString
						});
						aGInfoWindows.push(oGInfoWindow);
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
				// console.log("[unit.label] "+ oJson.datastreams[0].unit.label);
				// console.log("[unit.symbol] "+ oJson.datastreams[0].unit.symbol);
				// console.log("[unit.type] "+ oJson.datastreams[0].unit.type);
				// console.log("[location.lat] "+ oJson.location.lat);
				// console.log("[location.lon] "+ oJson.location.lon);
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
			config.visualizer = new GmcVisualizer();
		};
		(new GmcDataParser()).getData();
	}
})(jQuery);