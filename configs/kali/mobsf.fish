function mobsf --description 'run MobSF in docker on http://localhost:8000'
    docker run -it --rm --name mobsf -p 8000:8000 -v $HOME/.MobSF:/home/mobsf/.MobSF opensecurity/mobile-security-framework-mobsf:latest $argv
end
