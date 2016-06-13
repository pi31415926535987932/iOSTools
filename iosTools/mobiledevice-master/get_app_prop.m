#include "cli.h"

static char *expected_udid = NULL;
static char *app_bundle_id = NULL;
static char *app_key = NULL;

static void print_app(const void *key, const void *value, void *context)
{
  if ((key == NULL) || (value == NULL))
  {
    return;
  }

  NSString *got_bundle_id = (__bridge NSString*)key;
  NSString *expected_bundle_id = [NSString stringWithUTF8String:app_bundle_id];

  if ([got_bundle_id caseInsensitiveCompare:expected_bundle_id] != NSOrderedSame)
  {
    return;
  }

  NSString *expected_app_key = [NSString stringWithUTF8String:app_key];

  NSDictionary *dict = (__bridge NSDictionary*)value;
  for (NSString *key in dict)
  {
    if ([key caseInsensitiveCompare:expected_app_key] == NSOrderedSame)
    {
      printfNS(@"%@\n", [dict objectForKey:key]);
      device_unregister(0);
      return;
    }
  }

  device_unregister(1);
}

static void on_device_connected(struct am_device *device)
{
  if (!device_matches(device, expected_udid))
  {
    return;
  }

  device_delayed_unregister_aborted = true;
  device_connect(device);

  CFDictionaryRef apps;
  ASSERT_OR_EXIT(!AMDeviceLookupApplications(device, 0, &apps), "!AMDeviceLookupApplications\n");

  CFDictionaryApplyFunction(apps, print_app, NULL);
  CFRelease(apps);

  device_unregister(1);
}

int get_app_prop(int argc, char *argv[])
{
  int flag;
  char *endptr;
  int64_t timeout = -1;

  while ((flag = getopt(argc, argv, "u:t:")) != -1)
  {
    switch (flag)
    {
      case 'u':
        expected_udid = optarg;
        break;

      case 't':
        timeout = strtoll(optarg, &endptr, 10);
        break;

      default:
        help(argc, argv);
        return 1;
    }
  }

  argc -= optind;
  argv += optind;

  if (argc != 2)
  {
    return invalid_usage(argc, argv);
  }

  app_bundle_id = argv[0];
  app_key = argv[1];

  device_delayed_unregister_status = 1;
  device_register(on_device_connected, timeout);
  return 1;
}
