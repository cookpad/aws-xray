Enbed user information to segment:

```ruby
# In configuration phase
use Aws::Xray::Rack, capture_user_data: ->(env) { env['X-User-Id'] }

# Implementation image:
class Rack
  def call(env)
    @app.call(env)
    capture_user_data.call(env)
  end
```

---

`aws` field. Especially EC2 and ECS field.

---

Send in_progress segment.

---

`precursor_ids`.
