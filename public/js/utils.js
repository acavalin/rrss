(function ($) { $(function () {
// -----------------------------------------------------------------------------
$.extend($, {
  utils: {
    spinners: [
      $('<img>').attr('src','/images/spinner-normal.gif'),
      $('<img>').attr('src','/images/spinner-big.gif'),
      $('<img>').attr('src','/images/spinner-linear.gif'),
    ],
    
    spinner: function (index, attr) {
      attr = attr || '';
      var list = { normal: 0, big: 1, linear: 2, bigmsg: 3 };
      var num = typeof index == 'number' ? index : list[index];
      
      // small, msg + medium, horizontal balls
      return [
        '<img class="spinner" src="'+$.utils.spinners[0].attr('src')+'" '+attr+'>',
        '<img class="spinner" src="'+$.utils.spinners[1].attr('src')+'" '+attr+'>',
        '<img class="spinner" src="'+$.utils.spinners[2].attr('src')+'" '+attr+'>',
        '<p align="center">caricamento in corso<br><img src="'+$.utils.spinners[1].attr('src')+'" '+attr+'></p>',
      ][parseInt(num || 0)];
    },//spinner
    
    fix_toolbars_width: function (tbar) {
      var parent = tbar.parent();
      if (parent.attr('id') == 'item')
        tbar.width( parent.width() - 16 );
      else
        tbar.width( parent.get(0).scrollHeight > parent.height() ? (parent.width() - 16) : '100%' );
    },//fix_toolbars_width
    
    fw_url: function (url) {
      var prefix = $('body').data('forward_url'),
          link   = $('body').data('escape_fw_url') ? encodeURIComponent(url) : url,
          fw_url = (prefix.length > 0 ? (prefix+link) : link);
      $.ajax({
        url:      fw_url,
        type:     'GET',
        cache:    false,
        dataType: 'text',
      });
    },//fw_url
  },//utils
});
// -----------------------------------------------------------------------------
}); })(jQuery);
