require 'rdiscount'

def stylesheets_dir(framework)
  Compass::Frameworks[framework].stylesheets_directory
end

def stylesheet_key(item)
  [item[:framework], item[:stylesheet]].join("/")
end

def tree(item)
  @stylesheets ||= {}
  @stylesheets[stylesheet_key(item)] ||= begin
    file = File.join(stylesheets_dir(item[:framework]), item[:stylesheet])
    contents = File.read(file)
    Sass::Engine.new(contents).send :to_tree
  end
end

def imports(item)
  sass_tree = tree(item)
  imports = []
  sass_tree.children.each do |child|
    if child.is_a?(Sass::Tree::ImportNode)
      imports << child.imported_filename
    end
  end
  imports
end

def reference_path(options)
  stylesheet = options[:stylesheet]
  path = stylesheet_path(stylesheet)
  if path
    item = @items.detect do |i|
      i[:stylesheet] == path &&
      i.identifier =~ /^\/reference/
    end
    if item
      rep = item.reps.find { |r| r.name == :default }
      rep.path
    end
  end
end

def import_paths
  paths = Compass::Frameworks::ALL.inject([]) {|m, f| m << f.stylesheets_directory}
  paths.map!{|p|[p, '']}
  if @item[:stylesheet]
    paths << [File.join(Compass::Frameworks[@item[:framework]].stylesheets_directory,
                       File.dirname(@item[:stylesheet])), File.dirname(@item[:stylesheet])]
  end
  paths
end

def stylesheet_path(ss)
  possible_filenames_for_stylesheet(ss).each do |filename|
    import_paths.each do |import_path|
      full_path = File.join(import_path.first, filename)
      if File.exist?(full_path)
        return "#{import_path.last}#{"/" if import_path.last && import_path.last.length > 0}#{filename}"
      end
    end
  end
end

def possible_filenames_for_stylesheet(ss)
  ext = File.extname(ss)
  path = File.dirname(ss)
  path = path == "." ? "" : "#{path}/"
  base = File.basename(ss)[0..-(ext.size+1)]
  extensions = if ext.size > 0
    [ext]
  else
    [".sass", ".scss"]
  end
  basenames = [base, "_#{base}"]
  filenames = []
  basenames.each do |basename|
    extensions.each do |extension|
      filenames << "#{path}#{basename}#{extension}"
    end
  end
  filenames
end

def mixins(item)
  sass_tree = tree(item)
  mixins = []
  comment = nil
  sass_tree.children.each do |child|
    if child.is_a?(Sass::Tree::MixinDefNode)
      child.comment = comment
      comment = nil
      mixins << child
    elsif child.is_a?(Sass::Tree::CommentNode)
      comment ||= ""
      comment << "\n" unless comment.empty?
      comment << child.docstring
    else
      comment = nil
    end
  end
  mixins
end

def constants(item)
  sass_tree = tree(item)
  constants = []
  comment = nil
  sass_tree.children.each do |child|
    if child.is_a?(Sass::Tree::VariableNode)
      child.comment = comment
      comment = nil
      constants << child
    elsif child.is_a?(Sass::Tree::CommentNode)
      comment ||= ""
      comment << "\n" unless comment.empty?
      comment << child.docstring
    else
      comment = nil
    end
  end
  constants
end

def mixin_signature(mixin)
  mixin.sass_signature(:include)
end

def example_items
  @example_items ||= @items.select{|i| i[:example]}
end

def examples_for_item(item)
  @examples ||= {}
  @examples[item] ||= example_items.select do |i|
    i[:framework] == item[:framework] &&
    i[:stylesheet] == item[:stylesheet]
  end
end

def mixin_examples(item, mixin)
  examples_for_item(item).select do |i|
    i[:mixin] == mixin.name
  end.map{|i| i.reps.find{|r| r.name == :default}}
end
  

def mixin_source_dialog(mixin, &block)
  vars = {
    :html => {
      :id => "mixin-source-#{mixin.name}",
      :class => "mixin",
      :title => "Source for +#{mixin.name}"
    }
  }
  render 'dialog', vars, &block
end

def format_doc(docstring)
  if docstring
    RDiscount.new(docstring).to_html
  end
end
