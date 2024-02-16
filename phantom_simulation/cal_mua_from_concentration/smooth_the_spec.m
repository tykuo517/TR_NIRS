% smooth the spec
clc;clear;close all;

folder='measured_parameter';
output_folder='measured_parameter_smoothed';
file_name_arr={'20181211_IndiaInk_original_mua_cm.txt','20181211_pdms_mua_cm.txt','20181212_old_IndiaInk_original_mua_cm.txt','20190314_BingBond_PDMS_mua_cm.txt','20190314_QiaoYue_PDMS_mua_cm.txt','20190331_IndiaInk_original_mua_cm.txt'};
special_smooth_wl=1040; % the wl higher than this wl should be specially smooth
use_original_wl_arr={907:911};

mkdir(output_folder);

for i=1:length(file_name_arr)
    temp=load(fullfile(folder,file_name_arr{i}));
    %% sort
    [~,sort_index]=sort(temp(:,1));
    temp=temp(sort_index,:);
    
    figure();
    hold on;
    plot(temp(:,1),temp(:,2));
    
    %% smooth
    a=smooth(temp(:,2));
    
    %% use original data
    for j=1:length(use_original_wl_arr)
        min_index=min(find(temp(:,1)>=min(use_original_wl_arr{j})));
        max_index=max(find(temp(:,1)<=max(use_original_wl_arr{j})));
        a(min_index:max_index)=temp(min_index:max_index,2);
    end
    temp(:,2)=a;
    
    %% spectial smooth
    temp(temp(:,1)>special_smooth_wl,2)=smooth(temp(temp(:,1)>special_smooth_wl,2),20);
    plot(temp(:,1),temp(:,2));
    
    title(strrep(file_name_arr{i},'_',' '));
    legend({'original','smoothed'},'Location','best');
    %% save
    save(fullfile(output_folder,file_name_arr{i}),'temp','-ascii','-tabs');
    saveas(gcf,fullfile(output_folder,[strtok(file_name_arr{i},'.') '.png']));
    close all;
end