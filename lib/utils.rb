module Utils
  
  
  private # ____________________________________________________________________
  
  
  # returns a fake error item
  def err_item(name, exception)
    exception = Exception.new(exception) if exception.is_a?(String)
    {
      'name'     => name,
      'id'       => "ERROR_#{name}",
      'hash_id'  => "ERROR_#{name}",
      'link'     => '',
      'title'    => "#{name} ERROR",
      'guid'     => '',
      'content'  => %Q|ERROR: #{exception}\n#{'-'*40}\n<pre>#{(exception.backtrace||[]).join "\n"}</pre>|,
      'pub_date' => Time.now.strftime('%F %T')  ,
      'read'     => 0,
      'kept'     => 0,
      'modified' => 0,
      'comment'  => '',
    }
  end # err_item ---------------------------------------------------------------
end