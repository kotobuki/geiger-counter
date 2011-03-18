(function($)
{
  $.fn.testFunc = function(config)
  {
    config = $.extend(
    {
      'conf1': undefined,
      'conf2': undefined
    });

    var target = this;
    var elTagName = $('<p>').html("sss");
    $(target).append(elTagName);
  };
  
})(jQuery);




$(document).ready(function()
{
  $('#world').testFunc({conf1:"1", conf2:"2"});
  alert(1);
});