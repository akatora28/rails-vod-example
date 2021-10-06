# Ruby on Rails VOD (Video-On-Demand) Example  

To quickly get started, run the app in a docker container with:
```bash
docker-compose build
```
then
```bash
docker-compose up
```

The app will now be running and accessible via http://localhost:3000/

---

## Webpacker::Manifest::MissingEntryError in Videos#index Error
try running:
```bash
docker-compose run web bundle exec rake webpacker:install
```