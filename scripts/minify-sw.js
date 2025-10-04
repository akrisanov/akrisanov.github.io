const fs = require('fs');
const UglifyJS = require('uglify-js');

function minifyFile(inputPath, outputPath) {
    if (!fs.existsSync(inputPath)) {
        throw new Error(`Input file not found: ${inputPath}`);
    }
    const code = fs.readFileSync(inputPath, 'utf8');
    const result = UglifyJS.minify(code, {
        mangle: true,
        compress: {
            hoist_funs: true,
            unsafe: true,
            unsafe_comps: true,
            unsafe_Function: true,
            unsafe_math: true,
            unsafe_proto: true,
            unsafe_regexp: true,
            unsafe_undefined: true,
            drop_console: true,
        },
    });
    if (result.error) {
        throw result.error;
    }
    fs.writeFileSync(outputPath, result.code);
    console.log(`Minified ${inputPath} -> ${outputPath}`);
}

// Minify theme service worker
minifyFile('themes/abridge/static/sw.js', 'themes/abridge/static/sw.min.js');
