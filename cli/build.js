#!/usr/bin/env node

const coffee 	= require('coffeescript');
const path 		= require('path');
const fs   		= require('fs');

const root  = path.join(__dirname, '..');
const src   = path.join(root, 'src');
const build = path.join(root, 'js');

function compile(dir) {
	const stat = fs.lstatSync(dir);
	if(stat.isDirectory()) {

		const newFolder = path.join(build, dir.replace(src, ''));

		try {
			fs.mkdirSync(newFolder);
		} catch (error) { }

		const files = fs.readdirSync(dir);
		files.forEach((file) => {
			compile(path.join(dir, file));
		});
	}
	else {
		if(!dir.endsWith('.coffee')) {
			return;
		}

		const file 	= fs.readFileSync(dir);
		const plain = file.toString('utf8');
		const js	= coffee.compile(plain, {
			transpile: {
				// presets: ['@babel/preset-env']
				plugins: ['transform-es2015-modules-commonjs']
			}
		});

		const newFile = path.join(build, dir
			.replace(src, '')
			.replace('.coffee', '.js')
		);

		fs.writeFileSync(newFile, js);
	}
}

compile(src);
