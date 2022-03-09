module.exports = {
  config: {
    windowSize: [1200, 1600],
    updateChannel: 'stable',
    fontSize: 12,
    fontFamily: 'Iosevka, "JetBrains Mono"',
    fontWeight: '350',
    fontWeightBold: 'bold',
    lineHeight: 1,
    letterSpacing: 0,
    cursorShape: 'UNDERLINE',
    cursorBlink: true,
    selectionColor: 'rgba(248,28,229,0.3)',
    css: '',
    termCSS: '',
    showHamburgerMenu: '',
    padding: '20px 10px 10px 30px',
    shell: '',
    env: {},
    bell: false,
    copyOnSelect: true,
    defaultSSHApp: true,
    quickEdit: false,
    macOptionSelectionMode: 'vertical',
    webGLRenderer: false,
  },

  plugins: [
    'hyper-font-ligatures', 
    'hyperterm-gruvbox-dark', 
    'hyper-visual-bell', 
    'hyper-quit',
    'hyper-tabs-enhanced'
  ],

  localPlugins: [],

  keymaps: {
  },

  hyperTabs: {
    trafficButtons: true,
    tabIconsColored: true,
    closeAlign: 'right',
  }
};
