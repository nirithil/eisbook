homedir=getenv('HOME');
d=fullfile(homedir,'gup'); [~,~]=mkdir(d)
d=fullfile(homedir,'gup','mygup'); [~,~]=mkdir(d)
d=fullfile(homedir,'results'); [~,~]=mkdir(d)
d=fullfile(homedir,'mydata'); [~,~]=mkdir(d)
d=fullfile(homedir,'tmp'); [~,~]=mkdir(d)
[~,~]=unix(['ln -s /shared_data ' homedir]);
addpath([homedir,'/gup/mygup'],'/opt/guisdap/anal','/opt/guisdap/init')
clear homedir d
startup
