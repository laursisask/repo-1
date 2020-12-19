const base = require('./webpack.config');

module.exports = {
  ...base,
  mode: 'production',
  output: {...base.output, filename: 'radium.min.js'},
};
