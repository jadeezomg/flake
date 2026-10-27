# glamour style for glow, in the layout of glamour's dark.json (glamour
# v2.0.1). Colors come from the host palette variant
# (config.dotfiles.theme.palette). Code blocks use the Birds-of-Paradise
# syntax colors, which the ANSI colors of the palette repeat: orange-red
# keywords, orange functions, yellow-green strings, blue constants.
{ palette }:
let
  p = palette;
in
{
  document = {
    block_prefix = "\n";
    block_suffix = "\n";
    color = p.text-primary;
    margin = 2;
  };
  block_quote = {
    indent = 1;
    indent_token = "│ ";
    color = p.ansi-bright-black;
  };
  paragraph = { };
  list.level_indent = 2;
  heading = {
    block_suffix = "\n";
    color = p.accent-yellow;
    bold = true;
  };
  # The top heading is a badge: dark text on the yellow accent.
  h1 = {
    prefix = " ";
    suffix = " ";
    color = p.bg-secondary;
    background_color = p.accent-yellow;
    bold = true;
  };
  h2.prefix = "## ";
  h3.prefix = "### ";
  h4.prefix = "#### ";
  h5.prefix = "##### ";
  h6 = {
    prefix = "###### ";
    color = p.ansi-bright-black;
    bold = false;
  };
  text = { };
  strikethrough.crossed_out = true;
  emph.italic = true;
  strong.bold = true;
  hr = {
    color = p.ansi-bright-black;
    format = "\n--------\n";
  };
  item.block_prefix = "• ";
  enumeration.block_prefix = ". ";
  task = {
    ticked = "[✓] ";
    unticked = "[ ] ";
  };
  link = {
    color = p.ansi-blue;
    underline = true;
  };
  link_text = {
    color = p.ansi-cyan;
    bold = true;
  };
  image = {
    color = p.ansi-magenta;
    underline = true;
  };
  image_text = {
    color = p.ansi-bright-black;
    format = "Image: {{.text}} →";
  };
  code = {
    prefix = " ";
    suffix = " ";
    color = p.ansi-bright-yellow;
    background_color = p.bg-tertiary;
  };
  code_block = {
    color = p.text-primary;
    margin = 2;
    chroma = {
      text.color = p.text-primary;
      error = {
        color = p.text-secondary;
        background_color = p.accent-red;
      };
      comment = {
        color = p.ansi-bright-black;
        italic = true;
      };
      comment_preproc.color = p.ansi-magenta;
      keyword.color = p.ansi-bright-red;
      keyword_reserved.color = p.ansi-bright-red;
      keyword_namespace.color = p.ansi-bright-red;
      keyword_type.color = p.ansi-blue;
      operator.color = p.ansi-cyan;
      punctuation.color = p.text-tertiary;
      name.color = p.text-primary;
      name_builtin.color = p.ansi-blue;
      name_tag.color = p.ansi-bright-red;
      name_attribute.color = p.ansi-yellow;
      name_class = {
        color = p.ansi-yellow;
        bold = true;
      };
      name_constant.color = p.ansi-blue;
      name_decorator.color = p.ansi-magenta;
      name_exception = { };
      name_function.color = p.ansi-yellow;
      name_other = { };
      literal = { };
      literal_number.color = p.ansi-blue;
      literal_date = { };
      literal_string.color = p.ansi-bright-yellow;
      literal_string_escape.color = p.ansi-cyan;
      generic_deleted.color = p.ansi-red;
      generic_emph.italic = true;
      generic_inserted.color = p.ansi-green;
      generic_strong.bold = true;
      generic_subheading.color = p.ansi-bright-black;
      background.background_color = p.bg-secondary;
    };
  };
  table = { };
  definition_list = { };
  definition_term = { };
  definition_description.block_prefix = "\n🠶 ";
  html_block = { };
  html_span = { };
}
