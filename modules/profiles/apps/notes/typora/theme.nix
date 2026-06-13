{palette}: ''
  /* Birds of Paradise Gruvbox for Typora
   * Layout and Markdown markers follow the upstream Gruvbox Typora theme.
   * Colors are sourced from lib/theme-palette.nix via dotfilesLib.palette.
   */

  :root {
    --bg: ${palette.bg-primary};
    --bg0-h: ${palette.bg-secondary};
    --bg0-s: ${palette.bg-secondary};
    --bg1: ${palette.bg-tertiary};
    --bg2: ${palette.ansi-black};
    --bg3: ${palette.sidebar-border};
    --bg4: ${palette.ansi-bright-black};

    --fg: ${palette.text-primary};
    --fg0: ${palette.text-secondary};
    --fg1: ${palette.text-primary};
    --fg2: ${palette.text-tertiary};
    --fg3: ${palette.ansi-bright-white};
    --fg4: ${palette.ansi-bright-black};

    --red: ${palette.ansi-red};
    --red-dim: ${palette.ansi-bright-red};
    --green: ${palette.ansi-green};
    --green-dim: ${palette.ansi-bright-green};
    --yellow: ${palette.ansi-yellow};
    --yellow-dim: ${palette.accent-yellow};
    --blue: ${palette.ansi-blue};
    --blue-dim: ${palette.ansi-bright-blue};
    --purple: ${palette.ansi-magenta};
    --purple-dim: ${palette.ansi-bright-magenta};
    --aqua: ${palette.ansi-cyan};
    --aqua-dim: ${palette.ansi-bright-cyan};
    --orange: ${palette.ansi-yellow};
    --orange-dim: ${palette.ansi-bright-yellow};
    --gray: ${palette.ansi-bright-black};
    --selection: ${palette.line-highlight};

    --bg-color: var(--bg);
    --side-bar-bg-color: var(--bg0-s);
    --active-file-bg-color: var(--bg2);
    --active-file-text-color: var(--fg0);
    --text-color: var(--fg);
    --control-text-color: var(--fg2);
    --window-border: 1px solid var(--bg2);
    --rawblock-edit-panel-bd: var(--bg1);
    --item-hover-bg-color: var(--bg1);
    --primary-color: var(--blue-dim);
    --primary-btn-border-color: var(--blue-dim);
    --primary-btn-text-color: var(--bg);
  }

  html,
  body {
    font-size: 16px;
    color: var(--fg);
    background: var(--bg-color);
    font-family: system-ui, sans-serif;
  }

  #write {
    max-width: 980px;
    padding-left: 10ch;
    padding-right: 10ch;
    line-height: 1.65;
  }

  #write p {
    margin-top: 1rem;
    margin-bottom: 1rem;
  }

  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  [mdlike='h1'],
  [mdlike='h2'],
  [mdlike='h3'],
  [mdlike='h4'],
  [mdlike='h5'],
  [mdlike='h6'] {
    font-family: ui-monospace, monospace;
    font-weight: 700;
    line-height: 1.25;
  }

  h1,
  [mdlike='h1'] {
    color: var(--orange-dim);
    font-size: 2rem;
  }

  h2,
  [mdlike='h2'] {
    color: var(--yellow-dim);
    font-size: 1.6rem;
  }

  h3,
  [mdlike='h3'] {
    color: var(--green-dim);
    font-size: 1.3rem;
  }

  h4,
  h5,
  h6,
  [mdlike='h4'],
  [mdlike='h5'],
  [mdlike='h6'] {
    color: var(--aqua-dim);
  }

  h1::before { content: "# "; }
  h2::before { content: "## "; }
  h3::before { content: "### "; }
  h4::before { content: "#### "; }
  h5::before { content: "##### "; }
  h6::before { content: "###### "; }

  h1::before,
  h2::before,
  h3::before,
  h4::before,
  h5::before,
  h6::before {
    color: var(--gray);
  }

  a,
  .md-link,
  .cm-link {
    color: var(--blue-dim);
    text-decoration: none;
  }

  #write a:hover {
    color: var(--bg);
    background-color: var(--blue);
  }

  strong,
  #typora-source .cm-strong {
    color: var(--orange-dim);
  }

  em,
  #typora-source .cm-em {
    color: var(--purple-dim);
  }

  blockquote {
    color: var(--fg2);
    background-color: var(--bg1);
    border-left: 8px solid var(--yellow);
    border-top-right-radius: 5px;
    border-bottom-right-radius: 5px;
    padding: 0 20px;
  }

  table {
    border-collapse: collapse;
    border-spacing: 0;
    border: 1px solid var(--bg3);
    line-height: 1.6rem;
  }

  thead {
    color: var(--fg0);
    background-color: var(--bg1);
  }

  td,
  th {
    border-left: 1px solid var(--bg3);
    padding: 0.5em 1em;
  }

  pre.md-meta-block,
  .md-fences,
  .cm-s-inner,
  code {
    color: var(--fg);
    background-color: var(--bg0-h);
  }

  pre.md-meta-block {
    color: var(--fg3);
    border: 1px dashed var(--bg3);
    padding: 15px;
  }

  code {
    color: var(--orange-dim);
    border-radius: 3px;
    padding: 2px 4px;
  }

  .md-fences {
    border: 1px solid var(--bg2);
    border-radius: 3px;
    padding-top: 4px;
    padding-bottom: 4px;
  }

  .CodeMirror.cm-s-inner .CodeMirror-gutters {
    color: var(--fg4);
    background: var(--bg0-h);
    border: none;
  }

  .CodeMirror .CodeMirror-cursor,
  .CodeMirror.cm-s-inner .CodeMirror-cursor {
    border-left: 1px solid var(--fg0);
  }

  .CodeMirror .cm-keyword,
  .CodeMirror.cm-s-inner .cm-keyword,
  .CodeMirror .cm-tag,
  .CodeMirror.cm-s-inner .cm-tag {
    color: var(--red-dim);
  }

  .CodeMirror .cm-variable-2,
  .CodeMirror.cm-s-inner .cm-variable-2,
  .CodeMirror .cm-def,
  .CodeMirror.cm-s-inner .cm-def,
  .CodeMirror .cm-link,
  .CodeMirror.cm-s-inner .cm-link {
    color: var(--blue-dim);
  }

  .CodeMirror .cm-variable-3,
  .CodeMirror.cm-s-inner .cm-variable-3,
  .CodeMirror .cm-attribute,
  .CodeMirror.cm-s-inner .cm-attribute {
    color: var(--aqua-dim);
  }

  .CodeMirror .cm-builtin,
  .CodeMirror.cm-s-inner .cm-builtin,
  .CodeMirror .cm-meta,
  .CodeMirror.cm-s-inner .cm-meta {
    color: var(--orange-dim);
  }

  .CodeMirror .cm-atom,
  .CodeMirror.cm-s-inner .cm-atom,
  .CodeMirror .cm-number,
  .CodeMirror.cm-s-inner .cm-number {
    color: var(--purple-dim);
  }

  .CodeMirror .cm-string,
  .CodeMirror.cm-s-inner .cm-string {
    color: var(--green-dim);
  }

  .CodeMirror .cm-comment,
  .CodeMirror.cm-s-inner .cm-comment {
    color: var(--gray);
    font-style: italic;
  }

  .task-list-item input::before {
    color: var(--green-dim);
    background-color: var(--bg);
  }

  .task-list-item input:checked::before {
    color: var(--green);
  }

  mark {
    color: var(--bg);
    background: var(--yellow);
  }

  hr {
    border: 0;
    border-top: 1px dashed var(--bg3);
  }

  #typora-sidebar,
  .sidebar-footer,
  content,
  titlebar,
  #megamenu-content,
  .megamenu-opened header {
    background: var(--bg-color);
  }

  .file-list-item.active,
  .file-tree-node.active,
  .file-node-content:hover,
  .outline-item:hover,
  .menu-style-btn.active,
  .context-menu.dropdown-menu > .active > a,
  .context-menu.dropdown-menu > li > a:hover {
    color: var(--fg0);
    background-color: var(--bg2);
  }

  .btn,
  input,
  input.form-control,
  .modal-content,
  .popover,
  .dropdown-menu,
  .megamenu-menu,
  #outline-dropmenu,
  .typora-node #outline-dropmenu {
    color: var(--fg);
    background-color: var(--bg1);
    border-color: var(--bg2);
  }

  .btn.btn-primary {
    color: var(--bg);
    background-color: var(--blue-dim);
    border-color: var(--blue-dim);
  }

  ::selection,
  .CodeMirror div.CodeMirror-selected,
  .CodeMirror.cm-s-inner div.CodeMirror-selected,
  .CodeMirror .CodeMirror-line::selection,
  .CodeMirror.cm-s-inner .CodeMirror-line::selection,
  .CodeMirror .CodeMirror-line > span::selection,
  .CodeMirror.cm-s-inner .CodeMirror-line > span::selection,
  .CodeMirror .CodeMirror-line > span > span::selection,
  .CodeMirror.cm-s-inner .CodeMirror-line > span > span::selection {
    color: var(--fg0);
    background: var(--selection);
  }

  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    background: var(--bg);
  }

  ::-webkit-scrollbar-thumb {
    background: var(--bg3);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background: var(--bg4);
  }
''
