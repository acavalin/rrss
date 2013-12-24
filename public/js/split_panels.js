(function ($) { $(function () {
// -----------------------------------------------------------------------------
// frame emulation with DIV tags
//   p1, p2 :  panel items (left/right | top/bottom)
//   dir    :  direction (h|v)
//   sizes  :  array containing the size of the panels
$.split_panels = function (p1, p2, dir, sizes) {
  p1    = $(p1);
  p2    = $(p2);
  dir   = dir   || 'h';
  sizes = sizes || ['50%', '50%'];
  
  function get_options () {
    var options = {};
    
    if (dir == 'h') {
      options.handles = 'e';
      options.minWidth = parseInt(p1.parent().width() * 0.1);
      options.maxWidth = parseInt(p1.parent().width() * 0.9);
      options.resize  = function () { p2.width( p1.parent().width() - p1.width()  - 5 ); };
      p1.addClass('panel_left');  p1.css('width', sizes[0]);
      p2.addClass('panel_right'); p2.css('width', sizes[1]);
    } else {
      options.handles = 's';
      options.minHeight = parseInt(p1.parent().height() * 0.1);
      options.maxHeight = parseInt(p1.parent().height() * 0.9);
      options.resize  = function () { p2.height( p1.parent().height() - p1.height() - 5 ); };
      p1.addClass('panel_top');     p1.css('height', sizes[0]);
      p2.addClass('panel_bottom');  p2.css('height', sizes[1]);
    }//if-else
    
    return options;
  }//get_options
  
  p1.resizable($.extend(get_options(), {
    start: function () { $('body').data('resizing_panels', true ); },
    stop:  function () { $('body').data('resizing_panels', false); }
  }));
  
  // handle window resize
  $(window).resize(function (ev) {
    if (!$('body').data('resizing_panels')) {
      var options = get_options();
      $.each(options, function (k, v) { p1.resizable('option', k, v); } );
      options.resize();
    }//if
  }).resize();
}//split_panels
// -----------------------------------------------------------------------------
}); })(jQuery);
